# frozen_string_literal: true

module Purchasing
  # Convenience: reverse every remaining quantity on every line of a posted receipt
  # atomically. Creates one quantity_reversal correction per line (or fails with no
  # partial effect). Marks the receipt reversed when all lines are fully reversed.
  class ReversePurchaseReceipt
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt:,
      actor:,
      reason:,
      idempotency_key:,
      correlation_id: nil
    )
      @receipt = purchase_receipt
      @actor = actor
      @reason = reason
      @idempotency_key = idempotency_key
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "reason is required" if @reason.blank?
      raise Purchasing::Error, "idempotency key is required" if @idempotency_key.blank?

      payload = {
        purchase_receipt_id: @receipt.id,
        reason: @reason
      }
      op = Idempotency::OperationService.begin!(
        source_id: @receipt.id,
        operation_type: "reverse_purchase_receipt",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return PurchaseReceipt.find(op.operation.result_id) if op.operation.result_id

        raise Purchasing::Error, "idempotent replay missing result"
      end

      PurchaseReceipt.transaction do
        receipt = PurchaseReceipt.lock.find(@receipt.id)
        raise Purchasing::Error, "only posted receipts can be reversed" unless receipt.posted?

        lines = receipt.purchase_receipt_lines.includes(:corrections).order(:id).to_a
        raise Purchasing::Error, "receipt has no lines" if lines.empty?

        reversible = lines.select { |line| line.remaining_reversible_quantity.positive? }
        raise Purchasing::Error, "receipt has nothing left to reverse" if reversible.empty?

        # Whole-receipt reverse requires exact inversion on every line; compensating
        # adjustments are line-scoped only (purchase_receipts.compensate).
        # Nested line keys must be UUIDs (idempotency_operations.idempotency_key is uuid).
        corrections = reversible.map do |line|
          ReversePurchaseReceiptLine.call(
            purchase_receipt_line: line,
            actor: @actor,
            reason: @reason,
            quantity: line.remaining_reversible_quantity,
            idempotency_key: SecureRandom.uuid_v7,
            authorize_compensate: false,
            correlation_id: @correlation_id
          )
        end

        receipt.reload
        raise Purchasing::Error, "receipt was not fully reversed" unless receipt.reversed? ||
          receipt.purchase_receipt_lines.includes(:corrections).all?(&:fully_reversed?)

        receipt.update!(status: "reversed") unless receipt.reversed?

        Audit::Recorder.record!(
          action: "purchase_receipts.reverse",
          outcome: "succeeded",
          actor_user: @actor,
          store: receipt.store,
          subject: receipt,
          correlation_id: @correlation_id,
          after_values: {
            status: receipt.status,
            correction_ids: corrections.map(&:id)
          }
        )

        Outbox::Recorder.record!(
          event_type: "purchasing.receipt_reversed",
          aggregate: receipt,
          correlation_id: @correlation_id,
          occurred_at: Time.current,
          payload: {
            purchase_receipt_id: receipt.id,
            correction_ids: corrections.map(&:id)
          }
        )

        Idempotency::OperationService.complete!(
          op.operation,
          result_type: "PurchaseReceipt",
          result_id: receipt.id,
          result_payload: { id: receipt.id, status: receipt.status }
        )

        receipt
      end
    rescue Purchasing::Error, ActiveRecord::RecordInvalid => e
      fail_operation!(op, e.message)
      raise Purchasing::Error, e.message
    rescue StandardError => e
      fail_operation!(op, e.message)
      raise
    end

    private

    def fail_operation!(op, message)
      return unless defined?(op) && op && !op.replayed

      Idempotency::OperationService.fail!(op.operation, message: message)
    end
  end
end
