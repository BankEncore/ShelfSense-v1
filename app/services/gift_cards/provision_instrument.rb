# frozen_string_literal: true

module GiftCards
  class ProvisionInstrument
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(program:, store:, number: nil, customer: nil, activated_at: Time.current)
      @program = program
      @store = store
      @number = number
      @customer = customer
      @activated_at = activated_at
    end

    def call
      raise GiftCards::Error, "program is required" if @program.blank?
      raise GiftCards::Error, "program is not active" unless @program.active?
      raise GiftCards::Error, "store is required" if @store.blank?

      number = resolved_number
      validate_number!(number)
      account = StoredValue::OpenAccount.call(account_type: "gift_card")
      GiftCard.create!(
        gift_card_program: @program,
        stored_value_account: account,
        number: number,
        status: "active",
        customer: @customer,
        activated_at: @activated_at,
        activated_store: @store
      )
    end

    private

    def resolved_number
      if @program.system_generated?
        return GiftCards::Number.generate(@program) if @number.blank?

        GiftCards::Number.normalize(@number)
      else
        raise GiftCards::Error, "a card number is required" if @number.blank?

        GiftCards::Number.normalize(@number)
      end
    end

    def validate_number!(number)
      unless GiftCards::Number.shape_match?(number, program: @program)
        raise GiftCards::Error, "card number is not valid for this program"
      end
      if GiftCard.exists?(number_digest: GiftCards::Number.digest(number))
        raise GiftCards::Error, "card number is already in use"
      end
    end
  end
end
