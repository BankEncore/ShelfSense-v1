# frozen_string_literal: true

module GiftCards
  class CashOutEligibility
    Result = Struct.new(:eligible, :amount_cents, :reason, :requires_request_confirmation, :approval_required, keyword_init: true)

    def self.call(gift_card)
      new(gift_card).call
    end

    def initialize(gift_card)
      @gift_card = gift_card
    end

    def call
      program = @gift_card.gift_card_program
      balance = @gift_card.stored_value_account.balance_cents
      if program.cash_out_policy == "prohibited"
        return denied("cash-out is prohibited for this program")
      end
      unless @gift_card.active? && @gift_card.stored_value_account.active?
        return denied("gift card is not available for cash-out")
      end
      unless balance.positive?
        return denied("gift card has no remaining balance")
      end
      unless threshold_met?(program, balance)
        return denied("remaining balance is above the cash-out threshold")
      end

      Result.new(
        eligible: true,
        amount_cents: balance,
        reason: nil,
        requires_request_confirmation: program.cash_out_policy == "required_on_request_when_eligible",
        approval_required: program.cash_out_approval_required
      )
    end

    private

    def denied(reason)
      Result.new(
        eligible: false,
        amount_cents: 0,
        reason: reason,
        requires_request_confirmation: false,
        approval_required: false
      )
    end

    def threshold_met?(program, balance)
      threshold = program.cash_out_threshold_cents
      return true if threshold.blank?

      program.cash_out_threshold_inclusive? ? balance <= threshold : balance < threshold
    end
  end
end
