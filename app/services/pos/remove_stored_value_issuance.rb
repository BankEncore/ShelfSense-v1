# frozen_string_literal: true

module Pos
  class RemoveStoredValueIssuance
    Result = Data.define(:transaction, :operation, :removed_issuance_id, :cleared_tender_ids, :replayed)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, issuance:, operation_id:, confirm_clear_tenders: false)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @issuance = issuance
      @operation_id = operation_id
      @confirm_clear_tenders = confirm_clear_tenders
    end

    def call
      lease = nil
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)

      lease = Pos::OperationLease.begin!(
        register_id: @transaction.register_id,
        operation_id: @operation_id,
        command_payload: {
          transaction_id: @transaction.id,
          issuance_id: @issuance.id,
          expected_lock_version: @expected_lock_version.to_i
        },
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::REMOVE_WORKING_ISSUANCE_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        issuance = transaction.pos_stored_value_issuances.find(@issuance.id)
        Pos::IssuanceTenderClear.require_confirmation!(transaction, confirmed: @confirm_clear_tenders)

        before = audit_snapshot(issuance)
        cleared_ids = Pos::IssuanceTenderClear.clear!(transaction)
        issuance.destroy!
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        Audit::Recorder.record!(
          action: "pos.working_issuance.removed",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: transaction,
          before_values: before,
          metadata: { cleared_tender_ids: cleared_ids.map(&:to_s) }
        )
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::REMOVE_WORKING_ISSUANCE_FACT_TYPE,
          facts: { removed_issuance_id: issuance.id, cleared_tender_ids: cleared_ids }
        )
        result = Result.new(
          transaction: transaction,
          operation: operation,
          removed_issuance_id: issuance.id,
          cleared_tender_ids: cleared_ids,
          replayed: false
        )
      end
      result
    rescue Pos::PayloadMismatch, Pos::OperationLease::Error
      raise
    rescue StandardError
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise
    end

    private

    # Masked identity only. A pending gift-card number never reaches audit data.
    def audit_snapshot(issuance)
      {
        issuance_id: issuance.id.to_s,
        issuance_number: issuance.issuance_number,
        issuance_type: issuance.issuance_type,
        amount_cents: issuance.amount_cents,
        gift_card_program_id: issuance.gift_card_program_id&.to_s,
        masked_card_snapshot: masked_identity(issuance)
      }.compact
    end

    def masked_identity(issuance)
      return issuance.masked_card_snapshot if issuance.masked_card_snapshot.present?
      return if issuance.pending_card_number_last_four.blank?

      "#{issuance.pending_card_number_prefix}••••#{issuance.pending_card_number_last_four}"
    end

    def replay_result(operation)
      facts = operation.envelope.fetch("facts", {})
      Result.new(
        transaction: operation.pos_transaction,
        operation: operation,
        removed_issuance_id: facts["removed_issuance_id"],
        cleared_tender_ids: facts.fetch("cleared_tender_ids", []),
        replayed: true
      )
    end
  end
end
