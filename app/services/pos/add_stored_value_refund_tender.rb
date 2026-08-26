# frozen_string_literal: true

module Pos
  class AddStoredValueRefundTender
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      tender_type:,
      amount_cents:,
      destination_mode:,
      card_number: nil,
      gift_card_program: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @tender_type = tender_type
      @amount_cents = amount_cents.to_i
      @destination_mode = destination_mode.to_s
      @card_number = card_number.to_s.strip.presence
      @gift_card_program = gift_card_program
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "tender is not available" unless @tender_type.active?
      raise Pos::Error, "tender is not stored value" unless @tender_type.stored_value?
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?
      unless PosStoredValueTenderDetail::DESTINATION_MODES.include?(@destination_mode)
        raise Pos::Error, "refund destination is invalid"
      end

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.require_commercial_content!(transaction)
        raise Pos::Error, "transaction does not require a refund" unless Pos::Support.settlement_direction(transaction) == :refund
        remaining = Pos::Support.remaining_refund_cents(transaction)
        raise Pos::Error, "no remaining refund amount" if remaining <= 0
        raise Pos::Error, "amount is greater than remaining refund" if @amount_cents > remaining

        detail_attrs = build_detail_attrs!(transaction)
        tender = transaction.pos_tenders.new(
          direction: "refund",
          tender_number: Pos::Support.next_tender_number(transaction),
          amount_cents: @amount_cents,
          amount_presented_cents: nil,
          change_cents: nil
        )
        Pos::Support.snapshot_tender_identity!(tender, @tender_type)
        tender.save!
        tender.create_stored_value_tender_detail!(detail_attrs)
        Pos::Support.touch_working_transaction!(transaction)
        tender
      end
    rescue GiftCards::Error => e
      raise Pos::Error, e.message
    end

    private

    def build_detail_attrs!(transaction)
      case @destination_mode
      when "existing_account"
        existing_account_attrs!(transaction)
      when "customer_store_credit"
        store_credit_attrs!(transaction)
      when "new_gift_card"
        new_gift_card_attrs!(transaction)
      end
    end

    def existing_account_attrs!(transaction)
      case @tender_type.stored_value_account_type
      when "gift_card"
        raise Pos::Error, "original gift-card refund requires a presented card" if @card_number.blank?
        raise Pos::Error, "gift card cannot receive this refund" unless original_gift_card_funded?(transaction)

        card = GiftCards::Lookup.by_number(@card_number)
        raise Pos::Error, "gift card is not available" unless card&.active?
        unless original_gift_card_accounts(transaction).include?(card.stored_value_account_id)
          raise Pos::Error, "presented gift card does not match the original tender"
        end
        { destination_mode: "existing_account", stored_value_account: card.stored_value_account, gift_card: card, masked_card_snapshot: card.masked_number }
      when "trade_credit"
        raise Pos::Error, "trade credit is not a generic refund destination" unless @tender_type.allows_original_tender_refund?
        account_ids = original_trade_credit_accounts(transaction)
        raise Pos::Error, "trade credit can only return to the original account" if account_ids.empty?
        raise Pos::Error, "a customer is required" if transaction.customer.blank?

        account = StoredValueAccount.where(id: account_ids, customer_id: transaction.customer_id, account_type: "trade_credit")
                                    .where.not(status: "closed").order(:id).first
        raise Pos::Error, "original trade-credit account is not available" unless account&.active?

        { destination_mode: "existing_account", stored_value_account: account }
      when "store_credit"
        raise Pos::Error, "a customer is required" if transaction.customer.blank?
        raise Pos::Error, "customer must be an active canonical customer" unless transaction.customer.canonical? && transaction.customer.active?

        account = StoredValueAccount.where(customer_id: transaction.customer_id, account_type: "store_credit")
                                    .where.not(status: "closed").order(:id).first
        { destination_mode: "existing_account", stored_value_account: account }.compact
      else
        raise Pos::Error, "refund destination is invalid"
      end
    end

    def store_credit_attrs!(transaction)
      raise Pos::Error, "store credit cannot receive this refund" unless @tender_type.code == "store_credit"
      raise Pos::Error, "a customer is required" if transaction.customer.blank?
      raise Pos::Error, "customer must be an active canonical customer" unless transaction.customer.canonical? && transaction.customer.active?

      { destination_mode: "customer_store_credit" }
    end

    def new_gift_card_attrs!(transaction)
      raise Pos::Error, "new refund gift cards require the gift-card tender" unless @tender_type.code == "gift_card"
      raise Pos::Error, "new refund gift card is not allowed" unless @tender_type.allows_refund_instrument_replacement?
      raise Pos::Error, "new gift card cannot receive this refund" unless original_gift_card_funded?(transaction)

      program = @gift_card_program || GiftCards::Lookup.program_for(@card_number)
      raise Pos::Error, "gift-card program is required" if program.blank?
      raise Pos::Error, "gift-card program is not active" unless program.active?

      attrs = { destination_mode: "new_gift_card", gift_card_program: program }
      if program.manual_external?
        raise Pos::Error, "a card number is required" if @card_number.blank?

        number = GiftCards::Number.normalize(@card_number)
        unless GiftCards::Number.shape_match?(number, program: program)
          raise Pos::Error, "card number is not valid for this program"
        end
        if GiftCards::Lookup.by_number(number)
          raise Pos::Error, "card number is already in use"
        end
        attrs[:pending_card_number] = number
      elsif @card_number.present?
        raise Pos::Error, "system-generated refund cards cannot take a card number"
      end
      attrs
    end

    def original_gift_card_funded?(transaction)
      original_gift_card_accounts(transaction).any?
    end

    def original_gift_card_accounts(transaction)
      original_payment_accounts(transaction, "gift_card")
    end

    def original_trade_credit_accounts(transaction)
      original_payment_accounts(transaction, "trade_credit")
    end

    def original_payment_accounts(transaction, tender_code)
      original_ids = transaction.pos_transaction_lines.filter_map(&:original_transaction_line_id)
      return [] if original_ids.empty?

      original_transaction_ids = PosTransactionLine.where(id: original_ids).distinct.pluck(:pos_transaction_id)
      PosTender.where(pos_transaction_id: original_transaction_ids, tender_type: tender_code, direction: "payment")
               .includes(:stored_value_tender_detail)
               .filter_map { |tender| tender.stored_value_tender_detail&.stored_value_account_id }
               .uniq
    end
  end
end
