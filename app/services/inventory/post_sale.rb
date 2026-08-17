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
      variant = @line.product_variant
      store = @line.pos_transaction.store
      quantity_delta = -@line.quantity

      balance = Balances.lock_or_create!(store: store, product_variant: variant)
      effects = deplete(balance, quantity_delta)
      apply_negative_stock_policy!(effects)

      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
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
        quantity_delta: quantity_delta,
        value_delta_cents: effects[:value_delta_cents],
        valuation_method: "moving_average",
        entry_type: "depletion",
        source_type: "PosTransactionLine",
        source_id: @line.id,
        effect_sequence: 0,
        calculation_metadata: effects[:metadata],
        business_date: @business_date,
        occurred_at: @occurred_at
      )

      LedgerPairIntegrity.assert_pair!(ledger, valuation)

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
          pos_transaction_id: @line.pos_transaction_id,
          pos_transaction_line_id: @line.id,
          quantity_delta: quantity_delta,
          value_delta_cents: effects[:value_delta_cents]
        }
      )

      { ledger: ledger, valuation: valuation, balance: balance.reload }
    rescue LedgerPairIntegrity::Error => e
      raise Error, e.message
    end

    private

    def validate_request!
      tracking = @line.product_variant.derived_inventory_tracking
      raise Error, "variant is not quantity-tracked" unless tracking == "quantity"
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "line quantity must be positive" unless @line.quantity.to_i.positive?
    end

    def deplete(balance, quantity_delta)
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
        value_delta_cents: -removed_value,
        resulting_on_hand: qty - removal,
        resulting_value_cents: value - removed_value,
        metadata: { prior_quantity: qty, prior_value_cents: value }
      }
    end

    def apply_negative_stock_policy!(effects)
      return if effects[:resulting_on_hand] >= 0 && effects[:resulting_value_cents] >= 0

      raise Error, "posting would reduce on-hand or value below zero"
    end
  end
end
