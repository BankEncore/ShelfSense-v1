# frozen_string_literal: true

module Pos
  class ReturnToSaleClearTenders
    Result = Data.define(:transaction, :operation, :replayed)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, operation_id:, expected_lock_version:)
      @transaction = transaction
      @actor = actor
      @operation_id = operation_id
      @expected_lock_version = expected_lock_version
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
          expected_lock_version: @expected_lock_version
        },
        store_id: @transaction.store_id,
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::RETURN_TO_SALE_CLEAR_TENDERS_COMMAND_TYPE
      )
      return replay_result(lease.operation) if lease.replayed

      result = nil
      PosTransaction.transaction do
        operation = PosOperation.lock.find(lease.operation.id)
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        tenders = transaction.pos_tenders.ordered.to_a
        if tenders.any?(&:stored_value?)
          raise Pos::Error, "Return to Sale with stored-value tenders becomes available after Slice 7B"
        end

        removed_ids = tenders.map(&:id)
        Audit::Recorder.record!(
          action: "pos.working_tenders.returned_to_sale",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: transaction.store,
          register: transaction.register,
          subject: transaction,
          before_values: { tender_ids: removed_ids }
        )
        tenders.each(&:destroy!)
        Pos::Support.touch_working_transaction!(transaction) if tenders.any?
        Pos::CompleteWorkingOperation.call(
          operation: operation,
          fact_type: PosOperation::RETURN_TO_SALE_CLEAR_TENDERS_FACT_TYPE,
          facts: { removed_tender_ids: removed_ids }
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

    def replay_result(operation)
      Result.new(transaction: operation.pos_transaction, operation: operation, replayed: true)
    end
  end
end
