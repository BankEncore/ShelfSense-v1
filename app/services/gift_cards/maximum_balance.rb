# frozen_string_literal: true

module GiftCards
  module MaximumBalance
    module_function

    def assert!(account:, next_balance_cents:)
      return unless account.account_type == "gift_card"

      card = account.gift_card
      return if card.blank?

      maximum = card.gift_card_program.maximum_balance_cents
      return if maximum.blank?
      return if Integer(next_balance_cents) <= maximum

      raise StoredValue::Error, "credit would exceed the program maximum balance"
    end
  end
end
