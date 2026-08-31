# frozen_string_literal: true

module Pos
  class RemoveWorkingTender
    Result = Data.define(:transaction, :operation, :replayed)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, tender:, operation_id:)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @tender = tender
      @operation_id = operation_id
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
          tender_id: @tender.id,
          expected_lock_version: @expected_lock_version
        },
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::REMOVE_WORKING_TENDER_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        tender = transaction.pos_tenders.find(@tender.id)

        Audit::Recorder.record!(
          action: "pos.working_tender.removed",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: tender,
          before_values: tender.slice(
            "id", "tender_number", "tender_type", "tender_name", "behavioral_category",
            "direction", "amount_cents", "amount_presented_cents", "change_cents", "external_reference"
          ),
          metadata: stored_value_metadata(tender)
        )
        tender.destroy!
        Pos::Support.renumber_tenders!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::REMOVE_WORKING_TENDER_FACT_TYPE,
          facts: { removed_tender_id: @tender.id }
        )
        result = Result.new(transaction: transaction, operation: operation, replayed: false)
      end
      result
    rescue Pos::PayloadMismatch, Pos::OperationLease::Error
      raise
    rescue StandardError
      Pos::OperationLease.fail!(lease.operation) if lease&.operation&.reload&.status == "in_flight"
      raise
    end

    private

    # Working removal discards an unposted tender; no stored-value ledger entry
    # exists to reverse.
    def stored_value_metadata(tender)
      return {} unless tender.stored_value?

      detail = tender.stored_value_tender_detail
      {
        stored_value_ledger_affected: false,
        destination_mode: detail&.destination_mode,
        stored_value_account_id: detail&.stored_value_account_id,
        masked_card_snapshot: detail&.masked_card_snapshot
      }.compact
    end

    def replay_result(operation)
      Result.new(transaction: operation.pos_transaction, operation: operation, replayed: true)
    end
  end
end
