# frozen_string_literal: true

module Inventory
  # Valuation-only relief for authorized receipt-line compensation when physical
  # quantity cannot be exactly reversed (typically zero on-hand with residual value).
  # Does not deplete on-hand. Joins the caller's transaction.
  class CompensateReceiptLine
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      correction:,
      occurred_at:,
      business_date:,
      actor:,
      correlation_id: nil
    )
      @correction = correction
      @occurred_at = occurred_at
      @business_date = business_date
      @actor = actor
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      unless InventoryLedgerEntry.connection.transaction_open?
        raise Error, "CompensateReceiptLine must run inside the caller's transaction"
      end

      validate_request!

      line = PurchaseReceiptLine.lock.find(@correction.purchase_receipt_line_id)
      receipt = PurchaseReceipt.lock.find(line.purchase_receipt_id)
      variant = line.product_variant
      store = receipt.store
      balance = Balances.lock_or_create!(store: store, product_variant: variant)

      # Sold / already-zero on-hand: purchasing correction alone closes receipt qty.
      # Only clear residual carrying value when quantity is already zero.
      return { balance: balance, ledger: nil, valuation: nil } unless balance.on_hand_quantity.zero?
      return { balance: balance, ledger: nil, valuation: nil } if balance.inventory_value_cents.zero?

      value_delta_cents = -balance.inventory_value_cents
      resulting_value = 0

      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: nil,
        quantity_delta: 0,
        entry_type: "cost_correction",
        source_type: "PurchaseReceiptLineCorrection",
        source_id: @correction.id,
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
        quantity_delta: 0,
        value_delta_cents: value_delta_cents,
        acquisition_unit_cost_cents: nil,
        valuation_method: "moving_average",
        entry_type: "cost_correction",
        source_type: "PurchaseReceiptLineCorrection",
        source_id: @correction.id,
        effect_sequence: 0,
        calculation_metadata: {
          purchase_receipt_line_id: line.id,
          compensation: true,
          prior_value_cents: balance.inventory_value_cents,
          value_delta_cents: value_delta_cents
        },
        business_date: @business_date,
        occurred_at: @occurred_at
      )

      LedgerPairIntegrity.assert_pair!(ledger, valuation)
      balance.update!(inventory_value_cents: resulting_value)

      @correction.update!(
        inventory_source_type: "InventoryLedgerEntry",
        inventory_source_id: ledger.id
      )

      Outbox::Recorder.record!(
        event_type: "inventory.receipt_compensated",
        aggregate: @correction,
        correlation_id: @correlation_id,
        occurred_at: @occurred_at,
        payload: {
          store_id: store.id,
          product_variant_id: variant.id,
          purchase_receipt_line_id: line.id,
          purchase_receipt_line_correction_id: @correction.id,
          quantity_delta: 0,
          value_delta_cents: value_delta_cents
        }
      )

      { ledger: ledger, valuation: valuation, balance: balance.reload, correction: @correction }
    rescue LedgerPairIntegrity::Error => e
      raise Error, e.message
    end

    private

    def validate_request!
      raise Error, "correction is required" if @correction.blank?
      unless @correction.compensating_adjustment_reference?
        raise Error, "correction must be a compensating adjustment reference"
      end
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "quantity must be positive" unless @correction.quantity.to_i.positive?
    end
  end
end
