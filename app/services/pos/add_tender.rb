# frozen_string_literal: true

module Pos
  class AddTender
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, tender_type:, amount_cents:, external_reference: nil)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @external_reference = external_reference.to_s.strip.presence
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "use cash tender for Cash" if @tender_type.cash?
      raise Pos::Error, "use stored-value tender for stored value" if @tender_type.stored_value?
      raise Pos::Error, "tender is not available" unless @tender_type.active?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
      if @tender_type.reference_required? && @external_reference.blank?
        raise Pos::Error, "reference is required"
      end
      unless @tender_type.reference_captured?
        @external_reference = nil
      end

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.require_commercial_content!(transaction)
        raise Pos::Error, "transaction does not require payment" unless Pos::Support.settlement_direction(transaction) == :payment

        remaining = Pos::Support.remaining_payment_cents(transaction)
        raise Pos::Error, "no remaining amount due" if remaining <= 0
        if @amount_cents > remaining
          raise Pos::Error, "amount is greater than remaining due"
        end

        tender = transaction.pos_tenders.new(
          direction: "payment",
          tender_number: Pos::Support.next_tender_number(transaction),
          amount_cents: @amount_cents,
          amount_presented_cents: nil,
          change_cents: nil,
          external_reference: @external_reference
        )
        Pos::Support.snapshot_tender_identity!(tender, @tender_type)
        tender.save!
        Pos::Support.touch_working_transaction!(transaction)
        tender
      end
    end
  end
end
