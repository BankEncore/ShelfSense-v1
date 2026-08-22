# frozen_string_literal: true

module Inventory
  # Posts purchase-received quantity and merchandise value using moving weighted average.
  # Joins the caller's transaction. Ancillary receipt charges never enter value_delta_cents.
  class PostReceipt
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt_line:,
      occurred_at:,
      business_date:,
      actor:,
      correlation_id: nil
    )
      @line = purchase_receipt_line
      @occurred_at = occurred_at
      @business_date = business_date
      @actor = actor
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      unless InventoryLedgerEntry.connection.transaction_open?
        raise Error, "PostReceipt must run inside the caller's transaction"
      end

      validate_request!

      variant = @line.product_variant
      store = @line.purchase_receipt.store
      quantity_delta = @line.received_quantity
      value_delta_cents = quantity_delta * @line.actual_unit_cost_cents

      balance = Balances.lock_or_create!(store: store, product_variant: variant)
      effects = acquire_moving_average(balance, quantity_delta, value_delta_cents)

      persist_effects!(
        store: store,
        variant: variant,
        quantity_delta: quantity_delta,
        effects: effects
      )
    rescue LedgerPairIntegrity::Error => e
      raise Error, e.message
    end

    private

    def validate_request!
      tracking = @line.product_variant.derived_inventory_tracking
      unless tracking == "quantity"
        raise Error, "PostReceipt accepts only quantity-tracked merchandise in Phase 7"
      end
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "received quantity must be positive" unless @line.received_quantity.to_i.positive?
      raise Error, "actual unit cost must be nonnegative" if @line.actual_unit_cost_cents.to_i.negative?
    end

    def acquire_moving_average(balance, quantity_delta, value_delta_cents)
      qty = balance.on_hand_quantity
      value = balance.inventory_value_cents

      {
        balance: balance,
        value_delta_cents: value_delta_cents,
        resulting_on_hand: qty + quantity_delta,
        resulting_value_cents: value + value_delta_cents,
        metadata: {
          prior_quantity: qty,
          prior_value_cents: value,
          actual_unit_cost_cents: @line.actual_unit_cost_cents
        }
      }
    end

    def persist_effects!(store:, variant:, quantity_delta:, effects:)
      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: nil,
        quantity_delta: quantity_delta,
        entry_type: "receipt",
        source_type: "PurchaseReceiptLine",
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
        inventory_unit: nil,
        quantity_delta: quantity_delta,
        value_delta_cents: effects[:value_delta_cents],
        acquisition_unit_cost_cents: @line.actual_unit_cost_cents,
        valuation_method: "moving_average",
        entry_type: "acquisition",
        source_type: "PurchaseReceiptLine",
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
        event_type: "inventory.receipt_posted",
        aggregate: @line,
        correlation_id: @correlation_id,
        occurred_at: @occurred_at,
        payload: {
          store_id: store.id,
          product_variant_id: variant.id,
          purchase_receipt_id: @line.purchase_receipt_id,
          purchase_receipt_line_id: @line.id,
          quantity_delta: quantity_delta,
          value_delta_cents: effects[:value_delta_cents]
        }
      )

      { ledger: ledger, valuation: valuation, balance: balance.reload }
    end
  end
end
