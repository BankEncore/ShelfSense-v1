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

      tender = cash_tender
      return nil unless tender

      matching = candidates.select { |operation| payload_matches?(operation, tender) }
      matching.find { |operation| operation.status == "in_flight" } ||
        matching.find { |operation| operation.status == "failed" }
    end

    private

    def cash_tender
      @transaction.pos_tenders.find_by(tender_type: "cash")
    end

    def candidates
      PosOperation.where(
        pos_transaction_id: @transaction.id,
        command_type: PosOperation::COMMAND_TYPE,
        source_id: @transaction.register_id,
        status: %w[in_flight failed]
      )
    end

    def payload_matches?(operation, tender)
      payload = Pos::CompleteTransaction.command_payload(
        transaction: @transaction,
        operation_id: operation.id,
        expected_lock_version: @transaction.lock_version,
        expected_total_cents: @transaction.total_cents,
        amount_presented_cents: tender.amount_presented_cents
      )
      operation.command_payload_hash == Idempotency::CanonicalJson.hash(payload)
    end
  end
end
