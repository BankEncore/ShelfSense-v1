# frozen_string_literal: true

module Inventory
  class PostReturn
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(line:, occurred_at:, business_date:, actor:, correlation_id: nil)
      @line = line
      @occurred_at = occurred_at
      @business_date = business_date
      @actor = actor
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      unless InventoryLedgerEntry.connection.transaction_open?
        raise Error, "PostReturn must run inside the caller's transaction"
      end

      validate_request!
      tracking == "individual" ? post_individual! : post_quantity!
    rescue LedgerPairIntegrity::Error, ReturnValuation::Error => e
      raise Error, e.message
    end

    private

    def tracking
      @tracking ||= @line.product_variant.derived_inventory_tracking
    end

    def linked?
      @line.linked_return?
    end

    def original_line
      @original_line ||= @line.original_transaction_line
    end

    def validate_request!
      unless %w[quantity individual].include?(tracking)
        raise Error, "variant is not inventory-tracked"
      end
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "line quantity must be positive" unless @line.quantity.to_i.positive?
      raise Error, "line is not a return" unless @line.return?
      if linked?
        raise Error, "original sale line is required" if original_line.nil?
      elsif original_line.present?
        raise Error, "unlinked return cannot reference an original sale line"
      end
      return unless tracking == "individual"

      raise Error, "inventory unit is required" if @line.inventory_unit_id.blank?
      raise Error, "unit return quantity must be 1" unless @line.quantity == 1
    end

    def post_quantity!
      variant = @line.product_variant
      store = @line.pos_transaction.store
      quantity_delta = @line.quantity

      if linked?
        restored_value = allocated_inventory_value
        @valuation_basis = "linked_original_sale"
        balance = Balances.lock_or_create!(store: store, product_variant: variant)
      else
        balance = Balances.lock_or_create!(store: store, product_variant: variant)
        valuation = ReturnValuation.call(
          store: store,
          variant: variant,
          quantity: quantity_delta,
          balance: balance
        )
        restored_value = valuation.incoming_value_cents
        @valuation_basis = valuation.basis
      end

      effects = acquire_quantity(balance, quantity_delta, restored_value)

      persist_effects!(
        store: store,
        variant: variant,
        inventory_unit: nil,
        quantity_delta: quantity_delta,
        effects: effects,
        valuation_method: "moving_average"
      )
    end

    def post_individual!
      variant = @line.product_variant
      store = @line.pos_transaction.store
      balance = Balances.lock_or_create!(store: store, product_variant: variant)
      unit = lock_inventory_unit!
      raise Error, "unit must be removed" unless unit.removed?
      raise Error, "unit store mismatch" unless unit.store_id == store.id
      raise Error, "unit variant mismatch" unless unit.product_variant_id == variant.id
      if linked?
        raise Error, "return unit does not match the original sale" unless unit.id == original_line.inventory_unit_id
        restored_value = original_sale_value_magnitude
        @valuation_basis = "linked_original_sale"
      else
        valuation = ReturnValuation.call(
          store: store,
          variant: variant,
          quantity: 1,
          inventory_unit: unit,
          balance: balance
        )
        restored_value = valuation.incoming_value_cents
        @valuation_basis = valuation.basis
      end

      quantity_delta = 1
      effects = acquire_specific_identification(balance, restored_value)

      unit.update!(
        lifecycle_state: "on_hand",
        removed_at: nil,
        carrying_value_cents: restored_value
      )

      persist_effects!(
        store: store,
        variant: variant,
        inventory_unit: unit,
        quantity_delta: quantity_delta,
        effects: effects,
        valuation_method: "specific_identification"
      )
    end

    def lock_inventory_unit!
      InventoryUnit.lock.find(@line.inventory_unit_id)
    rescue ActiveRecord::RecordNotFound
      raise Error, "unit must be removed"
    end

    def persist_effects!(store:, variant:, inventory_unit:, quantity_delta:, effects:, valuation_method:)
      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity_delta: quantity_delta,
        entry_type: "return",
        source_type: "PosTransactionLine",
        source_id: @line.id,
        effect_sequence: 0,
        business_date: @business_date,
        occurred_at: @occurred_at,
        actor_type: "User",
        actor_id: @actor.id
      )

      valuation = InventoryValuationEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity_delta: quantity_delta,
        value_delta_cents: effects[:value_delta_cents],
        valuation_method: valuation_method,
        entry_type: "acquisition",
        source_type: "PosTransactionLine",
        source_id: @line.id,
        effect_sequence: 0,
        calculation_metadata: effects[:metadata],
        business_date: @business_date,
        occurred_at: @occurred_at
      )

      LedgerPairIntegrity.assert_pair!(ledger, valuation)

      balance = effects.fetch(:balance)
      balance.update!(
        on_hand_quantity: effects[:resulting_on_hand],
        inventory_value_cents: effects[:resulting_value_cents]
      )

      Outbox::Recorder.record!(
        event_type: "inventory.return_posted",
        aggregate: @line,
        correlation_id: @correlation_id,
        occurred_at: @occurred_at,
        payload: {
          store_id: store.id,
          product_variant_id: variant.id,
          inventory_unit_id: inventory_unit&.id,
          pos_transaction_id: @line.pos_transaction_id,
          pos_transaction_line_id: @line.id,
          original_transaction_line_id: original_line&.id,
          quantity_delta: quantity_delta,
          value_delta_cents: effects[:value_delta_cents],
          linked: linked?,
          valuation_basis: @valuation_basis
        }.compact
      )
      Audit::Recorder.record!(
        action: "inventory.return_posted",
        outcome: "succeeded",
        actor_user: @actor,
        actor_label: @actor.display_name,
        store: store,
        subject: @line,
        correlation_id: @correlation_id,
        after_values: {
          original_transaction_line_id: original_line&.id,
          quantity: @line.quantity,
          inventory_unit_id: inventory_unit&.id,
          value_restored_cents: effects[:value_delta_cents],
          valuation_basis: @valuation_basis
        }.compact
      )

      { ledger: ledger, valuation: valuation, balance: balance.reload }
    end

    def acquire_quantity(balance, quantity_delta, restored_value)
      qty = balance.on_hand_quantity
      value = balance.inventory_value_cents
      {
        balance: balance,
        value_delta_cents: restored_value,
        resulting_on_hand: qty + quantity_delta,
        resulting_value_cents: value + restored_value,
        metadata: quantity_metadata(qty, value)
      }
    end

    def acquire_specific_identification(balance, restored_value)
      qty = balance.on_hand_quantity
      value = balance.inventory_value_cents
      {
        balance: balance,
        value_delta_cents: restored_value,
        resulting_on_hand: qty + 1,
        resulting_value_cents: value + restored_value,
        metadata: quantity_metadata(qty, value).merge(inventory_unit_id: @line.inventory_unit_id)
      }
    end

    def quantity_metadata(qty, value)
      metadata = {
        prior_quantity: qty,
        prior_value_cents: value
      }
      metadata[:original_transaction_line_id] = original_line.id if original_line
      metadata[:valuation_basis] = @valuation_basis if @valuation_basis
      metadata
    end

    def allocated_inventory_value
      Pos::HistoricalReturnAllocation.call(
        original_line: original_line,
        requested_quantity: @line.quantity,
        excluding_line_id: @line.id
      ).inventory_value_cents
    end

    def original_sale_value_magnitude
      valuation = InventoryValuationEntry.find_by!(
        source_type: "PosTransactionLine",
        source_id: original_line.id,
        entry_type: "depletion"
      )
      -valuation.value_delta_cents
    end
  end
end
