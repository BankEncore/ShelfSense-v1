# frozen_string_literal: true

module Purchasing
  # Reverse an eligible posted purchase receipt line (exact inventory inverse).
  #
  # Compensating path: when exact reversal is unsafe (sold stock, residual value,
  # competing reservations), pass authorize_compensate: true with an actor who has
  # purchase_receipts.compensate. That records a compensating_adjustment_reference
  # (consuming reversible quantity) and may post valuation-only inventory relief when
  # on-hand is already zero with residual value. It does not deplete via PostAdjustment.
  # Fulfilled customer pickup is never undone — even with compensate — and remains a hard failure.
  class ReversePurchaseReceiptLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt_line:,
      actor:,
      reason:,
      idempotency_key:,
      quantity: nil,
      authorize_compensate: false,
      correlation_id: nil
    )
      @line = purchase_receipt_line
      @actor = actor
      @reason = reason
      @idempotency_key = idempotency_key
      @quantity = quantity
      @authorize_compensate = authorize_compensate
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "reason is required" if @reason.blank?
      raise Purchasing::Error, "idempotency key is required" if @idempotency_key.blank?

      payload = {
        purchase_receipt_line_id: @line.id,
        quantity: @quantity,
        reason: @reason,
        authorize_compensate: @authorize_compensate
      }
      op = Idempotency::OperationService.begin!(
        source_id: @line.id,
        operation_type: "reverse_purchase_receipt_line",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return PurchaseReceiptLineCorrection.find(op.operation.result_id) if op.operation.result_id

        raise Purchasing::Error, "idempotent replay missing result"
      end

      PurchaseReceiptLine.transaction do
        # Lock order: receipt/line → PO → balance (via inventory) → request / allocation
        line = PurchaseReceiptLine.lock.find(@line.id)
        receipt = PurchaseReceipt.lock.find(line.purchase_receipt_id)
        raise Purchasing::Error, "only posted receipt lines can be reversed" unless receipt.posted?

        quantity = (@quantity.presence || line.remaining_reversible_quantity).to_i
        raise Purchasing::Error, "nothing left to reverse on this line" unless quantity.positive?
        if quantity > line.remaining_reversible_quantity
          raise Purchasing::Error, "reversal quantity exceeds remaining received quantity"
        end

        po = PurchaseOrder.lock.find(line.purchase_order_line.purchase_order_id)
        PurchaseOrderLine.lock.find(line.purchase_order_line_id)

        occurred_at = Time.current
        business_date = BusinessDate.for_store(receipt.store, at: occurred_at)

        correction = PurchaseReceiptLineCorrection.create!(
          purchase_receipt_line: line,
          correction_type: "quantity_reversal",
          quantity: quantity,
          reason: @reason,
          recorded_by: @actor,
          recorded_at: occurred_at
        )

        begin
          Inventory::ReverseReceiptLine.call(
            correction: correction,
            occurred_at: occurred_at,
            business_date: business_date,
            actor: @actor,
            correlation_id: @correlation_id
          )
        rescue Inventory::ReverseReceiptLine::UnsafeReversalError => e
          correction.destroy!
          if e.reason_code == :fulfilled_allocation
            raise Purchasing::Error, e.message
          end
          return compensate!(
            line: line.reload,
            receipt: receipt,
            po: po,
            quantity: quantity,
            occurred_at: occurred_at,
            business_date: business_date,
            unsafe_message: e.message,
            op: op
          )
        end

        maybe_mark_receipt_reversed!(receipt)
        ClosePurchaseOrderIfComplete.call!(
          purchase_order: po.reload,
          actor: @actor,
          correlation_id: @correlation_id
        )
        reopen_po_if_needed!(po)

        Audit::Recorder.record!(
          action: "purchase_receipts.reverse_line",
          outcome: "succeeded",
          actor_user: @actor,
          store: receipt.store,
          subject: correction,
          correlation_id: @correlation_id,
          after_values: {
            purchase_receipt_line_id: line.id,
            quantity: quantity,
            correction_type: correction.correction_type
          }
        )

        Outbox::Recorder.record!(
          event_type: "purchasing.receipt_line_reversed",
          aggregate: correction,
          correlation_id: @correlation_id,
          occurred_at: occurred_at,
          payload: {
            purchase_receipt_id: receipt.id,
            purchase_receipt_line_id: line.id,
            correction_id: correction.id,
            quantity: quantity
          }
        )

        Idempotency::OperationService.complete!(
          op.operation,
          result_type: "PurchaseReceiptLineCorrection",
          result_id: correction.id,
          result_payload: { id: correction.id }
        )

        correction
      end
    rescue Purchasing::Error, Inventory::ReverseReceiptLine::Error, ActiveRecord::RecordInvalid => e
      fail_operation!(op, e.message)
      raise Purchasing::Error, e.message
    rescue StandardError => e
      fail_operation!(op, e.message)
      raise
    end

    private

    def compensate!(line:, receipt:, po:, quantity:, occurred_at:, business_date:, unsafe_message:, op:)
      unless @authorize_compensate
        raise Purchasing::Error,
              "#{unsafe_message}. To authorize compensation without exact inventory reversal, " \
              "retry with authorize_compensate and purchase_receipts.compensate."
      end

      remaining_before = line.remaining_reversible_quantity
      if quantity > remaining_before
        raise Purchasing::Error, "compensation quantity exceeds remaining received quantity"
      end

      value_delta = -line.reversal_value_cents_for(quantity, remaining_before: remaining_before)

      correction = PurchaseReceiptLineCorrection.create!(
        purchase_receipt_line: line,
        correction_type: "compensating_adjustment_reference",
        quantity: quantity,
        value_delta_cents: value_delta,
        reason: @reason,
        recorded_by: @actor,
        recorded_at: occurred_at
      )

      Inventory::CompensateReceiptLine.call(
        correction: correction,
        occurred_at: occurred_at,
        business_date: business_date,
        actor: @actor,
        correlation_id: @correlation_id
      )

      maybe_mark_receipt_reversed!(receipt)
      ClosePurchaseOrderIfComplete.call!(
        purchase_order: po.reload,
        actor: @actor,
        correlation_id: @correlation_id
      )
      reopen_po_if_needed!(po)

      Audit::Recorder.record!(
        action: "purchase_receipts.compensate",
        outcome: "succeeded",
        actor_user: @actor,
        store: receipt.store,
        subject: correction,
        correlation_id: @correlation_id,
        after_values: {
          purchase_receipt_line_id: line.id,
          quantity: quantity,
          value_delta_cents: value_delta
        },
        metadata: { unsafe_message: unsafe_message }
      )

      Outbox::Recorder.record!(
        event_type: "purchasing.receipt_line_compensated",
        aggregate: correction,
        correlation_id: @correlation_id,
        occurred_at: occurred_at,
        payload: {
          purchase_receipt_line_id: line.id,
          correction_id: correction.id,
          quantity: quantity,
          value_delta_cents: value_delta
        }
      )

      Idempotency::OperationService.complete!(
        op.operation,
        result_type: "PurchaseReceiptLineCorrection",
        result_id: correction.id,
        result_payload: { id: correction.id, compensated: true }
      )

      correction
    end

    def maybe_mark_receipt_reversed!(receipt)
      receipt.reload
      lines = receipt.purchase_receipt_lines.includes(:corrections)
      return unless lines.all?(&:fully_reversed?)

      receipt.update!(status: "reversed")
    end

    def reopen_po_if_needed!(po)
      po = PurchaseOrder.lock.find(po.id)
      return unless po.closed?
      return if po.purchase_order_lines.all? { |line| line.open_quantity.zero? }

      po.update!(status: "sent", closed_at: nil)
    end

    def fail_operation!(op, message)
      return unless defined?(op) && op && !op.replayed

      Idempotency::OperationService.fail!(op.operation, message: message)
    end
  end
end
