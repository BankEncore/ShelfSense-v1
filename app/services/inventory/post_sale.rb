# frozen_string_literal: true

module Inventory
  class PostSale
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
        raise Error, "PostSale must run inside the caller's transaction"
      end

      validate_request!
      tracking == "individual" ? post_individual! : post_quantity!
    rescue LedgerPairIntegrity::Error => e
      raise Error, e.message
    end

    private

    def tracking
      @tracking ||= @line.product_variant.derived_inventory_tracking
    end

    def validate_request!
      unless %w[quantity individual].include?(tracking)
        raise Error, "variant is not inventory-tracked"
      end
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "line quantity must be positive" unless @line.quantity.to_i.positive?
      return unless tracking == "individual"

      raise Error, "inventory unit is required" if @line.inventory_unit_id.blank?
      raise Error, "unit sale quantity must be 1" unless @line.quantity == 1
    end

    def post_quantity!
      variant = @line.product_variant
      store = @line.pos_transaction.store
      quantity_delta = -@line.quantity

      balance = Balances.lock_or_create!(store: store, product_variant: variant)
      lock_pickup_allocation!
      assert_availability!(store: store, variant: variant, quantity_delta: quantity_delta, balance: balance)
      effects = deplete_moving_average(balance, quantity_delta)
      apply_negative_stock_policy!(effects)

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
      raise Error, "unit must be on hand" unless unit.on_hand?
      raise Error, "unit store mismatch" unless unit.store_id == store.id
      raise Error, "unit variant mismatch" unless unit.product_variant_id == variant.id

      quantity_delta = -1
      lock_pickup_allocation!(inventory_unit: unit)
      assert_availability!(
        store: store,
        variant: variant,
        quantity_delta: quantity_delta,
        inventory_unit: unit,
        balance: balance
      )
      carrying_value_cents = unit.carrying_value_cents
      effects = deplete_specific_identification(balance, carrying_value_cents)
      apply_negative_stock_policy!(effects)

      unit.update!(lifecycle_state: "removed", removed_at: Time.current)

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
      InventoryUnit.uncached { InventoryUnit.lock.find(@line.inventory_unit_id) }
    rescue ActiveRecord::RecordNotFound
      raise Error, "unit must be on hand"
    end

    def persist_effects!(store:, variant:, inventory_unit:, quantity_delta:, effects:, valuation_method:)
      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: inventory_unit,
        quantity_delta: quantity_delta,
        entry_type: "sale",
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
        entry_type: "depletion",
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
        event_type: "inventory.sale_posted",
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
          value_delta_cents: effects[:value_delta_cents]
        }.compact
      )

      { ledger: ledger, valuation: valuation, balance: balance.reload }
    end

    def deplete_moving_average(balance, quantity_delta)
      qty = balance.on_hand_quantity
      value = balance.inventory_value_cents
      removal = -quantity_delta
      raise Error, "insufficient on-hand quantity" if removal > qty

      removed_value =
        if qty <= 0
          0
        elsif removal >= qty && qty.positive?
          value
        else
          Costing.value_removed_cents(
            current_value_cents: value,
            current_quantity: qty,
            removal_magnitude: [ removal, qty ].min
          )
        end

      {
        balance: balance,
        value_delta_cents: -removed_value,
        resulting_on_hand: qty - removal,
        resulting_value_cents: value - removed_value,
        metadata: { prior_quantity: qty, prior_value_cents: value }
      }
    end

    def deplete_specific_identification(balance, carrying_value_cents)
      qty = balance.on_hand_quantity
      value = balance.inventory_value_cents
      raise Error, "insufficient on-hand quantity" if qty < 1

      {
        balance: balance,
        value_delta_cents: -carrying_value_cents,
        resulting_on_hand: qty - 1,
        resulting_value_cents: value - carrying_value_cents,
        metadata: {
          prior_quantity: qty,
          prior_value_cents: value,
          inventory_unit_id: @line.inventory_unit_id
        }
      }
    end

    def apply_negative_stock_policy!(effects)
      return if effects[:resulting_on_hand] >= 0 && effects[:resulting_value_cents] >= 0

      raise Error, "posting would reduce on-hand or value below zero"
    end

    def assert_availability!(store:, variant:, quantity_delta:, inventory_unit: nil, balance: nil)
      Availability.assert_depletion_allowed!(
        store: store,
        variant: variant,
        quantity_delta: quantity_delta,
        inventory_unit: inventory_unit,
        exclude_allocation_id: @line.customer_request_allocation_id,
        balance: balance
      )
    rescue Availability::Error => e
      raise Error, e.message
    end

    # Lock order: InventoryBalance → InventoryUnit (Used) → allocation / request.
    def lock_pickup_allocation!(inventory_unit: nil)
      allocation_id = @line.customer_request_allocation_id
      return if allocation_id.blank?

      allocation = CustomerRequestAllocation.lock.find(allocation_id)
      raise Error, "allocation is not reserved for pickup" unless allocation.reserved?

      request = allocation.customer_request
      raise Error, "customer request is not available for pickup" unless request.available?
      raise Error, "allocation store mismatch" unless request.store_id == @line.pos_transaction.store_id
      raise Error, "allocation variant mismatch" unless request.product_variant_id == @line.product_variant_id

      if allocation.used_unit?
        raise Error, "pickup line requires the allocated inventory unit" if inventory_unit.blank?
        raise Error, "inventory unit does not match the allocation" unless allocation.inventory_unit_id == inventory_unit.id
      elsif inventory_unit.present?
        raise Error, "standard pickup cannot include an inventory unit"
      end

      allocation
    rescue ActiveRecord::RecordNotFound
      raise Error, "allocation is not reserved for pickup"
    end
  end
end
