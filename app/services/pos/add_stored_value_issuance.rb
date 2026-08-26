# frozen_string_literal: true

module Pos
  class AddStoredValueIssuance
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      issuance_type:,
      amount_cents:,
      gift_card_program: nil,
      card_number: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @issuance_type = issuance_type.to_s
      @amount_cents = amount_cents.to_i
      @gift_card_program = gift_card_program
      @card_number = card_number.to_s.strip.presence
    end

    def call
      Pos::Support.authorize!(@actor, @transaction.store)
      Pos::Support.require_active_context!(@transaction.store, @transaction.register)
      Pos::Support.require_transaction_cashier!(@actor, @transaction)
      raise Pos::Error, "issuance type is invalid" unless PosStoredValueIssuance::ISSUANCE_TYPES.include?(@issuance_type)
      raise Pos::Error, "amount must be positive" unless @amount_cents.positive?

      PosTransaction.transaction do
        transaction = Pos::Support.lock_working_transaction!(@transaction, @expected_lock_version)
        Pos::Support.clear_working_tenders!(transaction)
        issuance = case @issuance_type
        when "activation"
          build_activation!(transaction)
        when "reload"
          build_reload!(transaction)
        end
        issuance.save!
        Pos::Support.refresh_totals!(transaction)
        Pos::Support.touch_working_transaction!(transaction)
        issuance
      end
    rescue GiftCards::Error => e
      raise Pos::Error, e.message
    end

    private

    def build_activation!(transaction)
      program = @gift_card_program || GiftCards::Lookup.program_for(@card_number)
      raise Pos::Error, "gift-card program is required" if program.blank?
      raise Pos::Error, "gift-card program is not active" unless program.active?
      if program.minimum_activation_cents.present? && @amount_cents < program.minimum_activation_cents
        raise Pos::Error, "activation is below the program minimum"
      end
      if program.maximum_balance_cents.present? && @amount_cents > program.maximum_balance_cents
        raise Pos::Error, "activation exceeds the program maximum"
      end

      issuance = transaction.pos_stored_value_issuances.new(
        issuance_number: Pos::Support.next_issuance_number(transaction),
        issuance_type: "activation",
        amount_cents: @amount_cents,
        gift_card_program: program,
        number_authority: program.number_authority
      )
      if program.manual_external?
        raise Pos::Error, "a card number is required" if @card_number.blank?

        number = GiftCards::Number.normalize(@card_number)
        unless GiftCards::Number.shape_match?(number, program: program)
          raise Pos::Error, "card number is not valid for this program"
        end
        if GiftCards::Lookup.by_number(number) || PosStoredValueIssuance.exists?(pending_card_number_digest: GiftCards::Number.digest(number))
          raise Pos::Error, "card number is already in use"
        end
        issuance.pending_card_number = number
      elsif @card_number.present?
        raise Pos::Error, "system-generated activations cannot take a card number"
      end
      issuance
    end

    def build_reload!(transaction)
      raise Pos::Error, "a card number is required" if @card_number.blank?

      card = GiftCards::Lookup.by_number(@card_number)
      raise Pos::Error, "gift card is not available" unless card
      raise Pos::Error, "gift card is not available" unless card.active?
      raise Pos::Error, "reload is not allowed for this program" unless card.gift_card_program.reload_allowed?
      program = card.gift_card_program
      next_balance = card.stored_value_account.balance_cents + @amount_cents
      if program.maximum_balance_cents.present? && next_balance > program.maximum_balance_cents
        raise Pos::Error, "reload exceeds the program maximum"
      end

      transaction.pos_stored_value_issuances.new(
        issuance_number: Pos::Support.next_issuance_number(transaction),
        issuance_type: "reload",
        amount_cents: @amount_cents,
        gift_card_program: program,
        gift_card: card,
        number_authority: program.number_authority,
        masked_card_snapshot: card.masked_number
      )
    end
  end
end
