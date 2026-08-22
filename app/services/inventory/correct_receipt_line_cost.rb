# frozen_string_literal: true

module Inventory
  # Valuation-only delta for a cost error when physical quantity is correct.
  # Joins the caller's transaction. Source must be a cost_correction correction.
  # Posts paired ledger/valuation rows with quantity_delta = 0.
  class CorrectReceiptLineCost
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
        raise Error, "CorrectReceiptLineCost must run inside the caller's transaction"
      end

      validate_request!

      line = PurchaseReceiptLine.lock.find(@correction.purchase_receipt_line_id)
      receipt = PurchaseReceipt.lock.find(line.purchase_receipt_id)
      raise Error, "only posted receipt lines can be cost-corrected" unless receipt.posted?
      raise Error, "cannot cost-correct a fully reversed receipt line" if line.fully_reversed?

      value_delta_cents = @correction.value_delta_cents.to_i
      variant = line.product_variant
      store = receipt.store
      balance = Balances.lock_or_create!(store: store, product_variant: variant)

      resulting_value = balance.inventory_value_cents + value_delta_cents
      if resulting_value.negative?
        raise Error, "cost correction would reduce inventory value below zero"
      end
      if balance.on_hand_quantity.zero? && !resulting_value.zero?
        raise Error, "cost correction would leave residual value with zero on-hand"
      end

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
        event_type: "inventory.receipt_cost_corrected",
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
      raise Error, "correction must be a cost correction" unless @correction.cost_correction?
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "value_delta_cents must be nonzero" if @correction.value_delta_cents.to_i.zero?
    end
  end
end
