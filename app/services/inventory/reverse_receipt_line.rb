# frozen_string_literal: true

module Inventory
  # Exact inverse of eligible posted receipt-line physical and valuation effects.
  # Joins the caller's transaction. Source must be a quantity_reversal correction.
  #
  # Unsafe when:
  # - an allocation created by the receipt line is fulfilled (completed pickup),
  # - exact inverse would drive on-hand or value below zero, or
  # - reservation availability would be violated after releasing this line's active allocation.
  #
  # When unsafe, callers must not force an approximate reverse. Use an authorized
  # compensating inventory adjustment (purchase_receipts.compensate) with an explicit
  # cross-reference correction instead — see Purchasing::ReversePurchaseReceiptLine.
  class ReverseReceiptLine
    class Error < StandardError; end
    class UnsafeReversalError < Error
      attr_reader :reason_code

      def initialize(message, reason_code:)
        super(message)
        @reason_code = reason_code
      end
    end

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
        raise Error, "ReverseReceiptLine must run inside the caller's transaction"
      end

      validate_request!

      line = PurchaseReceiptLine.lock.find(@correction.purchase_receipt_line_id)
      receipt = PurchaseReceipt.lock.find(line.purchase_receipt_id)
      raise Error, "only posted receipt lines can be reversed" unless receipt.posted?

      quantity = @correction.quantity.to_i
      prior_reversed = line.corrections.quantity_reversals.where.not(id: @correction.id).sum(:quantity)
      remaining_before = line.received_quantity - prior_reversed
      raise Error, "reversal quantity exceeds remaining received quantity" if quantity > remaining_before

      original_ledger = InventoryLedgerEntry.find_by!(
        source_type: "PurchaseReceiptLine",
        source_id: line.id,
        effect_sequence: 0
      )
      original_valuation = InventoryValuationEntry.find_by!(
        source_type: "PurchaseReceiptLine",
        source_id: line.id,
        effect_sequence: 0
      )

      # Exact inverse of the original unit cost for the reversed quantity (not current average).
      quantity_delta = -quantity
      value_delta_cents = -(quantity * line.actual_unit_cost_cents)

      allocation = CustomerRequestAllocation.lock.find_by(purchase_receipt_line_id: line.id)
      if allocation&.fulfilled?
        raise UnsafeReversalError.new(
          "cannot reverse receipt line after customer pickup was fulfilled; " \
          "use an authorized compensating adjustment (purchase_receipts.compensate) if inventory " \
          "must be corrected without undoing the completed pickup",
          reason_code: :fulfilled_allocation
        )
      end

      variant = line.product_variant
      store = receipt.store
      balance = Balances.lock_or_create!(store: store, product_variant: variant)

      resulting_qty = balance.on_hand_quantity + quantity_delta
      resulting_value = balance.inventory_value_cents + value_delta_cents
      if resulting_qty.negative? || resulting_value.negative?
        raise UnsafeReversalError.new(
          "exact receipt reversal is unsafe (on-hand or value would go below zero); " \
          "use an authorized compensating adjustment with purchase_receipts.compensate",
          reason_code: :insufficient_stock
        )
      end
      if resulting_qty.zero? && !resulting_value.zero?
        raise UnsafeReversalError.new(
          "exact receipt reversal is unsafe (zero quantity with residual value); " \
          "use an authorized compensating adjustment with purchase_receipts.compensate",
          reason_code: :residual_value
        )
      end

      active_allocation = allocation&.reserved? ? allocation : nil
      begin
        Availability.assert_depletion_allowed!(
          store: store,
          variant: variant,
          quantity_delta: quantity_delta,
          balance: balance,
          exclude_allocation_id: active_allocation&.id
        )
      rescue Availability::Error => e
        raise UnsafeReversalError.new(
          "#{e.message}; use an authorized compensating adjustment with purchase_receipts.compensate",
          reason_code: :availability
        )
      end

      if active_allocation
        request = CustomerRequest.lock.find(active_allocation.customer_request_id)
        release_allocation!(active_allocation, request)
      end

      full_reverse = quantity == line.received_quantity && prior_reversed.zero?
      ledger = InventoryLedgerEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: nil,
        quantity_delta: quantity_delta,
        entry_type: "reversal",
        source_type: "PurchaseReceiptLineCorrection",
        source_id: @correction.id,
        effect_sequence: 0,
        business_date: @business_date,
        occurred_at: @occurred_at,
        actor_type: "User",
        actor_id: @actor.id,
        reversal_of: full_reverse ? original_ledger : nil
      )

      valuation = InventoryValuationEntry.create!(
        store: store,
        product_variant: variant,
        inventory_unit: nil,
        quantity_delta: quantity_delta,
        value_delta_cents: value_delta_cents,
        acquisition_unit_cost_cents: line.actual_unit_cost_cents,
        valuation_method: "moving_average",
        entry_type: "reversal",
        source_type: "PurchaseReceiptLineCorrection",
        source_id: @correction.id,
        effect_sequence: 0,
        calculation_metadata: {
          reversal_of_valuation_id: original_valuation.id,
          purchase_receipt_line_id: line.id,
          quantity: quantity
        },
        business_date: @business_date,
        occurred_at: @occurred_at,
        reversal_of: full_reverse ? original_valuation : nil
      )

      LedgerPairIntegrity.assert_pair!(ledger, valuation)

      balance.update!(
        on_hand_quantity: resulting_qty,
        inventory_value_cents: resulting_value
      )

      @correction.update!(
        inventory_source_type: "InventoryLedgerEntry",
        inventory_source_id: ledger.id
      )

      Outbox::Recorder.record!(
        event_type: "inventory.receipt_reversed",
        aggregate: @correction,
        correlation_id: @correlation_id,
        occurred_at: @occurred_at,
        payload: {
          store_id: store.id,
          product_variant_id: variant.id,
          purchase_receipt_line_id: line.id,
          purchase_receipt_line_correction_id: @correction.id,
          quantity_delta: quantity_delta,
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
      raise Error, "correction must be a quantity reversal" unless @correction.quantity_reversal?
      raise Error, "occurred_at is required" if @occurred_at.blank?
      raise Error, "business_date is required" if @business_date.blank?
      raise Error, "actor is required" if @actor.blank?
      raise Error, "quantity must be positive" unless @correction.quantity.to_i.positive?
    end

    def release_allocation!(allocation, request)
      allocation.update!(
        status: "released",
        released_at: Time.current,
        released_by: @actor,
        release_reason: "receipt line reversed: #{@correction.reason}"
      )

      return unless request.available?

      po_statuses = request.orders.includes(:purchase_order).filter_map { |order| order.purchase_order&.status }
      if po_statuses.any? { |status| %w[sent closed].include?(status) }
        request.update!(status: "ordered")
      else
        request.update!(status: "special_order_pending")
      end
    end
  end
end
