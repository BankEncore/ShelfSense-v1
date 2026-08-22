# frozen_string_literal: true

module Purchasing
  # Cost-only correction for a posted receipt line. Does not change physical quantity
  # or rewrite the posted receipt line's actual_unit_cost_cents.
  class CorrectPurchaseReceiptLineCost
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt_line:,
      actor:,
      reason:,
      idempotency_key:,
      corrected_unit_cost_cents: nil,
      value_delta_cents: nil,
      correlation_id: nil
    )
      @line = purchase_receipt_line
      @actor = actor
      @reason = reason
      @idempotency_key = idempotency_key
      @corrected_unit_cost_cents = corrected_unit_cost_cents
      @value_delta_cents = value_delta_cents
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "reason is required" if @reason.blank?
      raise Purchasing::Error, "idempotency key is required" if @idempotency_key.blank?

      payload = {
        purchase_receipt_line_id: @line.id,
        corrected_unit_cost_cents: @corrected_unit_cost_cents,
        value_delta_cents: @value_delta_cents,
        reason: @reason
      }
      op = Idempotency::OperationService.begin!(
        source_id: @line.id,
        operation_type: "correct_purchase_receipt_line_cost",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return PurchaseReceiptLineCorrection.find(op.operation.result_id) if op.operation.result_id

        raise Purchasing::Error, "idempotent replay missing result"
      end

      PurchaseReceiptLine.transaction do
        line = PurchaseReceiptLine.lock.find(@line.id)
        receipt = PurchaseReceipt.lock.find(line.purchase_receipt_id)
        raise Purchasing::Error, "only posted receipt lines can be cost-corrected" unless receipt.posted?
        raise Purchasing::Error, "cannot cost-correct a fully reversed line" if line.fully_reversed?

        remaining_qty = line.remaining_reversible_quantity
        raise Purchasing::Error, "no remaining quantity to cost-correct" unless remaining_qty.positive?

        value_delta = resolve_value_delta!(line, remaining_qty)
        occurred_at = Time.current
        business_date = BusinessDate.for_store(receipt.store, at: occurred_at)

        correction = PurchaseReceiptLineCorrection.create!(
          purchase_receipt_line: line,
          correction_type: "cost_correction",
          quantity: nil,
          value_delta_cents: value_delta,
          reason: @reason,
          recorded_by: @actor,
          recorded_at: occurred_at
        )

        Inventory::CorrectReceiptLineCost.call(
          correction: correction,
          occurred_at: occurred_at,
          business_date: business_date,
          actor: @actor,
          correlation_id: @correlation_id
        )

        Audit::Recorder.record!(
          action: "purchase_receipts.correct_cost",
          outcome: "succeeded",
          actor_user: @actor,
          store: receipt.store,
          subject: correction,
          correlation_id: @correlation_id,
          after_values: {
            purchase_receipt_line_id: line.id,
            value_delta_cents: value_delta
          }
        )

        Outbox::Recorder.record!(
          event_type: "purchasing.receipt_cost_corrected",
          aggregate: correction,
          correlation_id: @correlation_id,
          occurred_at: occurred_at,
          payload: {
            purchase_receipt_id: receipt.id,
            purchase_receipt_line_id: line.id,
            correction_id: correction.id,
            value_delta_cents: value_delta
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
    rescue Purchasing::Error, Inventory::CorrectReceiptLineCost::Error, ActiveRecord::RecordInvalid => e
      fail_operation!(op, e.message)
      raise Purchasing::Error, e.message
    rescue StandardError => e
      fail_operation!(op, e.message)
      raise
    end

    private

    def resolve_value_delta!(line, remaining_qty)
      if @value_delta_cents.present?
        delta = @value_delta_cents.to_i
        raise Purchasing::Error, "value_delta_cents must be nonzero" if delta.zero?

        return delta
      end

      if @corrected_unit_cost_cents.nil?
        raise Purchasing::Error, "corrected_unit_cost_cents or value_delta_cents is required"
      end

      corrected = @corrected_unit_cost_cents.to_i
      raise Purchasing::Error, "corrected unit cost must be nonnegative" if corrected.negative?

      target_extended = corrected * remaining_qty
      delta = target_extended - line.effective_merchandise_value_cents
      raise Purchasing::Error, "corrected unit cost equals current effective cost" if delta.zero?

      delta
    end

    def fail_operation!(op, message)
      return unless defined?(op) && op && !op.replayed

      Idempotency::OperationService.fail!(op.operation, message: message)
    end
  end
end
