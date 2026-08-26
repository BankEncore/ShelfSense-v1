# frozen_string_literal: true

module Pos
  class AddStoredValueTender
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(transaction:, actor:, expected_lock_version:, tender_type:, amount_cents:, card_number: nil)
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @card_number = card_number.to_s.strip.presence
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "tender is not available" unless @tender_type.active?
      raise Pos::Error, "tender is not stored value" unless @tender_type.stored_value?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.require_commercial_content!(transaction)
        raise Pos::Error, "cannot redeem stored value on a ticket with gift-card issuance" if transaction.pos_stored_value_issuances.any?
        raise Pos::Error, "transaction does not require payment" unless Pos::Support.settlement_direction(transaction) == :payment
        remaining = Pos::Support.remaining_payment_cents(transaction)
        raise Pos::Error, "no remaining amount due" if remaining <= 0
        raise Pos::Error, "amount is greater than remaining due" if @amount_cents > remaining

        account = resolve_account!(transaction)
        if duplicate_account?(transaction, account)
          raise Pos::Error, "this stored-value account is already on the transaction"
        end
        if account.balance_cents < @amount_cents
          raise Pos::Error, "stored-value balance is insufficient"
        end

        tender = transaction.pos_tenders.new(
          direction: "payment",
          tender_number: Pos::Support.next_tender_number(transaction),
          amount_cents: @amount_cents,
          amount_presented_cents: nil,
          change_cents: nil
        )
        Pos::Support.snapshot_tender_identity!(tender, @tender_type)
        tender.save!
        card = account.gift_card
        tender.create_stored_value_tender_detail!(
          destination_mode: "existing_account",
          stored_value_account: account,
          gift_card: card,
          masked_card_snapshot: card&.masked_number
        )
        Pos::Support.touch_working_transaction!(transaction)
        tender
      end
    rescue GiftCards::Error => e
      raise Pos::Error, e.message
    end

    private

    def resolve_account!(transaction)
      case @tender_type.stored_value_account_type
      when "gift_card"
        raise Pos::Error, "a card number is required" if @card_number.blank?

        card = GiftCards::Lookup.by_number(@card_number)
        raise Pos::Error, "gift card is not available" unless card&.active?

        card.stored_value_account
      when "store_credit", "trade_credit"
        customer = transaction.customer
        raise Pos::Error, "a customer is required" if customer.blank?
        raise Pos::Error, "customer must be an active canonical customer" unless customer.canonical? && customer.active?

        account = StoredValueAccount.where(customer_id: customer.id, account_type: @tender_type.stored_value_account_type)
                                    .where.not(status: "closed").order(:id).first
        raise Pos::Error, "customer stored-value account is not available" unless account&.active?

        account
      else
        raise Pos::Error, "tender is not stored value"
      end
    end

    def duplicate_account?(transaction, account)
      transaction.pos_tenders.payments.any? { |tender|
        tender.stored_value_tender_detail&.stored_value_account_id == account.id
      }
    end
  end
end
