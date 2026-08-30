# frozen_string_literal: true

module Pos
  class ReplaceTender
    Result = Data.define(:transaction, :tender, :operation, :replayed)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:, tender:, actor:, operation_id:, expected_lock_version:,
      amount_cents:, amount_presented_cents: nil, external_reference: nil
    )
      @transaction = transaction
      @tender = tender
      @actor = actor
      @operation_id = operation_id
      @expected_lock_version = expected_lock_version
      @amount_cents = amount_cents.to_i
      @amount_presented_cents = amount_presented_cents.presence&.to_i
      @external_reference = external_reference.to_s.strip.presence
    end

    def call
      lease = nil
      authorize!
      raise Pos::Error, "stored-value tender correction becomes available after Slice 7B" if @tender.stored_value?
      if @tender.behavioral_category == "card"
        raise Pos::Error, "card tenders must be removed and re-authorized externally before recording a replacement"
      end

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: command_payload,
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::REPLACE_WORKING_TENDER_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        original = transaction.pos_tenders.find(@tender.id)
        raise Pos::Error, "stored-value tender correction becomes available after Slice 7B" if original.stored_value?
        if original.behavioral_category == "card"
          raise Pos::Error, "card tenders must be removed and re-authorized externally before recording a replacement"
        end

        replacement = build_replacement!(transaction, original)
        before = audit_snapshot(original)
        original.destroy!
        replacement.save!
        Pos::Support.renumber_tenders!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        Audit::Recorder.record!(
          action: "pos.working_tender.replaced",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: replacement,
          before_values: before,
          after_values: audit_snapshot(replacement)
        )
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::REPLACE_WORKING_TENDER_FACT_TYPE,
          facts: { replaced_tender_id: original.id, replacement_tender_id: replacement.id }
        )
        result = Result.new(transaction: transaction, tender: replacement, operation: operation, replayed: false)
      end
      result
    rescue Pos::PayloadMismatch, Pos::OperationLease::Error
      raise
    rescue StandardError
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise
    end

    private

    def authorize!
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
    end

    def command_payload
      {
        transaction_id: @transaction.id,
        tender_id: @tender.id,
        expected_lock_version: @expected_lock_version,
        amount_cents: @amount_cents,
        amount_presented_cents: @amount_presented_cents,
        external_reference: @external_reference
      }
    end

    def build_replacement!(transaction, original)
      type = original.configured_tender_type
      raise Pos::Error, "tender is not available" unless type.active?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
      validate_reference!(type)

      available =
        if original.direction == "refund"
          Pos::Support.remaining_refund_cents(transaction, except: original)
        else
          Pos::Support.remaining_payment_cents(transaction, except: original)
        end
      label = original.direction == "refund" ? "refund" : "amount due"
      raise Pos::Error, "no remaining #{label}" unless available.positive?
      raise Pos::Error, "amount is greater than remaining #{label}" if @amount_cents > available
      raise Pos::Error, "tender does not allow refunds" if original.direction == "refund" && !type.allows_refund?

      replacement = transaction.pos_tenders.new(
        direction: original.direction,
        tender_number: original.tender_number,
        amount_cents: @amount_cents,
        external_reference: type.reference_captured? ? @external_reference : nil
      )
      Pos::Support.snapshot_tender_identity!(replacement, type)
      apply_cash_values!(replacement, original, transaction, available) if type.cash?
      replacement
    end

    def apply_cash_values!(replacement, original, transaction, available)
      if original.direction == "refund"
        replacement.amount_presented_cents = nil
        replacement.change_cents = nil
        return
      end

      presented = @amount_presented_cents || @amount_cents
      raise Pos::Error, "presented amount must be positive" unless presented.positive?
      if available == transaction.signed_net_cents && presented < available
        raise Pos::Error, "presented amount is less than amount due"
      end
      applied = [ presented, available ].min
      raise Pos::Error, "applied amount does not match cash presented" unless @amount_cents == applied

      replacement.amount_presented_cents = presented
      replacement.change_cents = presented - applied
      replacement.external_reference = nil
    end

    def validate_reference!(type)
      raise Pos::Error, "reference is required" if type.reference_required? && @external_reference.blank?
    end

    def audit_snapshot(tender)
      tender.slice(
        "id", "tender_number", "tender_type", "tender_name", "behavioral_category",
        "direction", "amount_cents", "amount_presented_cents", "change_cents", "external_reference"
      )
    end

    def replay_result(operation)
      replacement_id = operation.envelope.dig("facts", "replacement_tender_id")
      Result.new(
        transaction: operation.pos_transaction,
        tender: PosTender.find_by(id: replacement_id),
        operation: operation,
        replayed: true
      )
    end
  end
end
