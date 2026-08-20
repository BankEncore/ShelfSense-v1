# frozen_string_literal: true

module Inventory
  class PostPostVoid
    class Error < StandardError; end

    CONFLICT = Pos::PostVoidIntegrity::CONFLICT

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
        raise Error, "PostPostVoid must run inside the caller's transaction"
      end

      validate_request!
      tracking == "individual" ? post_individual! : post_quantity!
    rescue LedgerPairIntegrity::Error, ActiveRecord::RecordNotUnique
      raise Error, CONFLICT
    end

    private

    def tracking
      @tracking ||= @line.product_variant.derived_inventory_tracking
    end

    def source_line
      @source_line ||= @line.post_void_source_line
    end

    def validate_request!
      unless %w[quantity individual].include?(tracking)
        raise Error, "variant is not inventory-tracked"
      end
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "line is not a post-void reversal" unless @line.post_void_generated?
      raise Error, "source line is required" if source_line.nil?
      return unless tracking == "individual"

      raise Error, "inventory unit is required" if @line.inventory_unit_id.blank?
      raise Error, "unit quantity must be 1" unless @line.quantity == 1
    end

    def post_quantity!
      store = @line.pos_transaction.store
      variant = @line.product_variant
      balance = Balances.lock_or_create!(store: store, product_variant: variant)
      persist_inverse!(inventory_unit: nil, balance: balance)
    end

    def post_individual!
      store = @line.pos_transaction.store
      variant = @line.product_variant
      balance = Balances.lock_or_create!(store: store, product_variant: variant)
      unit = InventoryUnit.lock.find(@line.inventory_unit_id)
      raise Error, CONFLICT unless unit.store_id == store.id
      raise Error, CONFLICT unless unit.product_variant_id == variant.id

      source_ledger = source_ledger_entry
      if source_ledger.quantity_delta.negative?
        raise Error, CONFLICT unless unit.removed?
      else
        raise Error, CONFLICT unless unit.on_hand?
        unless unit.carrying_value_cents == source_valuation_entry.value_delta_cents.abs
          raise Error, CONFLICT
        end
      end

      persist_inverse!(inventory_unit: unit, balance: balance)
    end

    def persist_inverse!(inventory_unit:, balance:)
      source_ledger = source_ledger_entry
      source_valuation = source_valuation_entry
      quantity_delta = -source_ledger.quantity_delta
      value_delta = -source_valuation.value_delta_cents
      variant = @line.product_variant
      store = @line.pos_transaction.store
      resulting_qty = balance.on_hand_quantity + quantity_delta
      resulting_value = balance.inventory_value_cents + value_delta
      if resulting_qty.negative? || resulting_value.negative? || (resulting_qty.zero? && !resulting_value.zero?)
        raise Error, CONFLICT
      end

      if inventory_unit
        if source_ledger.quantity_delta.negative?
          inventory_unit.update!(
            lifecycle_state: "on_hand",
            removed_at: nil,
            carrying_value_cents: value_delta
          )
        else
          inventory_unit.update!(lifecycle_state: "removed", removed_at: Time.current)
        end
      end

      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity_delta: quantity_delta,
        entry_type: "reversal",
        source_type: "PosTransactionLine",
        source_id: @line.id,
        effect_sequence: 0,
        business_date: @business_date,
        occurred_at: @occurred_at,
        actor_type: "User",
        actor_id: @actor.id,
        reversal_of: source_ledger
      )

      valuation = InventoryValuationEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity_delta: quantity_delta,
        value_delta_cents: value_delta,
        valuation_method: source_valuation.valuation_method,
        entry_type: "reversal",
        source_type: "PosTransactionLine",
        source_id: @line.id,
        effect_sequence: 0,
        calculation_metadata: { reversal_of_valuation_id: source_valuation.id },
        business_date: @business_date,
        occurred_at: @occurred_at,
        reversal_of: source_valuation
      )

      LedgerPairIntegrity.assert_pair!(ledger, valuation)
      balance.update!(on_hand_quantity: resulting_qty, inventory_value_cents: resulting_value)

      Audit::Recorder.record!(
        action: "inventory.post_void_posted",
        outcome: "succeeded",
        actor_user: @actor,
        store: store,
        subject: @line,
        correlation_id: @correlation_id,
        after_values: {
          quantity_delta: quantity_delta,
          value_delta_cents: value_delta,
          source_line_id: source_line.id
        }
      )
      Outbox::Recorder.record!(
        event_type: "inventory.post_void_posted",
        aggregate: @line,
        correlation_id: @correlation_id,
        occurred_at: @occurred_at,
        payload: {
          store_id: store.id,
          product_variant_id: variant.id,
          inventory_unit_id: inventory_unit&.id,
          pos_transaction_id: @line.pos_transaction_id,
          pos_transaction_line_id: @line.id,
          quantity_delta: quantity_delta,
          value_delta_cents: value_delta
        }.compact
      )
    end

    def source_ledger_entry
      @source_ledger_entry ||= InventoryLedgerEntry.find_by!(
        source_type: "PosTransactionLine",
        source_id: source_line.id,
        effect_sequence: 0
      )
    end

    def source_valuation_entry
      @source_valuation_entry ||= InventoryValuationEntry.find_by!(
        source_type: "PosTransactionLine",
        source_id: source_line.id,
        effect_sequence: 0
      )
    end
  end
end
