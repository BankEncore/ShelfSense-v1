# frozen_string_literal: true

module Pos
  class FindCompletionOperation
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:)
      @transaction = transaction
      @actor = actor
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      return nil unless @transaction.working?
      return nil unless Pos::Support.exact_settlement?(@transaction)

      matching = candidates.select { |operation| payload_matches?(operation) }
      matching.find { |operation| operation.status == "in_flight" } ||
        matching.find { |operation| operation.status == "failed" }
    end

    private

    def candidates
      PosOperation.where(
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::COMMAND_TYPE,
        source_id: @transaction.register_id,
        status: %w[in_flight failed]
      ).order(created_at: :desc, id: :desc)
    end

    def payload_matches?(operation)
      payload = Pos::CompleteTransaction.command_payload(
        transaction: @transaction,
        operation_id: operation.id,
        expected_lock_version: @transaction.lock_version,
        expected_total_cents: @transaction.total_cents,
        expected_signed_net_cents: @transaction.signed_net_cents
      )
      Pos::CompleteTransaction.payload_hash_matches?(operation.command_payload_hash, payload)
    end
  end
end
