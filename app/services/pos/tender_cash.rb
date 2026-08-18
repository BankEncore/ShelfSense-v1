# frozen_string_literal: true

module Pos
  class TenderCash
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, amount_presented_cents:)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @amount_presented_cents = amount_presented_cents.to_i
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "presented amount must be positive" unless @amount_presented_cents.positive?

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        raise Pos::Error, "transaction has no merchandise" if transaction.pos_transaction_lines.none?
        if @amount_presented_cents < transaction.total_cents
          raise Pos::Error, "presented amount is less than amount due"
        end

        applied = transaction.total_cents
        change = @amount_presented_cents - applied
        Pos::Support.clear_working_tenders!(transaction)
        tender = transaction.pos_tenders.create!(
          tender_type: "cash",
          direction: "payment",
          amount_cents: applied,
          amount_presented_cents: @amount_presented_cents,
          change_cents: change
        )
        transaction.update!(updated_at: Time.current)
        tender
      end
    end
  end
end
