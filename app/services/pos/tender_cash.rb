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
        Pos::Support.require_commercial_content!(transaction)

        cash_type = Pos::Support.cash_tender_type
        raise Pos::Error, "Cash is not available" unless cash_type.active?

        existing = transaction.pos_tenders.cash.payments.first
        raise Pos::Error, "transaction does not require payment" unless Pos::Support.settlement_direction(transaction) == :payment
        remaining = Pos::Support.remaining_payment_cents(transaction, except: existing)
        raise Pos::Error, "no remaining amount due" if remaining <= 0

        if remaining == transaction.signed_net_cents && @amount_presented_cents < remaining
          raise Pos::Error, "presented amount is less than amount due"
        end

        if @amount_presented_cents >= remaining
          applied = remaining
          change = @amount_presented_cents - applied
        else
          applied = @amount_presented_cents
          change = 0
        end

        tender = existing || transaction.pos_tenders.new(
          direction: "payment",
          tender_number: Pos::Support.next_tender_number(transaction)
        )
        Pos::Support.snapshot_tender_identity!(tender, cash_type)
        tender.assign_attributes(
          amount_cents: applied,
          amount_presented_cents: @amount_presented_cents,
          change_cents: change,
          external_reference: nil
        )
        tender.save!
        Pos::Support.touch_working_transaction!(transaction)
        tender
      end
    end
  end
end
