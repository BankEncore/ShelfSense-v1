# frozen_string_literal: true

module Pos
  class AddRefundTender
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
      raise Pos::Error, "tender is not available" unless @tender_type.active?
      raise Pos::Error, "tender does not allow refunds" unless @tender_type.allows_refund?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
      if @tender_type.reference_required? && @external_reference.blank?
        raise Pos::Error, "reference is required"
      end
      unless @tender_type.reference_captured?
        @external_reference = nil
      end

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        raise Pos::Error, "transaction has no merchandise" if transaction.pos_transaction_lines.none?
        raise Pos::Error, "transaction does not require a refund" if transaction.signed_net_cents >= 0
        unless Pos::Support.settlement_direction(transaction) == :refund
          raise Pos::Error, "transaction does not require a refund"
        end

        existing = @tender_type.cash? ? transaction.pos_tenders.cash.refunds.first : nil
        remaining = Pos::Support.remaining_refund_cents(transaction, except: existing)
        raise Pos::Error, "no remaining refund due" if remaining <= 0
        if @amount_cents > remaining
          raise Pos::Error, "amount is greater than remaining refund"
        end

        tender = existing || transaction.pos_tenders.new(
          direction: "refund",
          tender_number: Pos::Support.next_tender_number(transaction)
        )
        Pos::Support.snapshot_tender_identity!(tender, @tender_type)
        tender.assign_attributes(
          direction: "refund",
          amount_cents: @amount_cents,
          amount_presented_cents: nil,
          change_cents: nil,
          external_reference: @external_reference
        )
        tender.save!
        Pos::Support.touch_working_transaction!(transaction)
        tender
      end
    end
  end
end
