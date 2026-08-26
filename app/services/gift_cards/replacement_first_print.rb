# frozen_string_literal: true

module GiftCards
  class ReplacementFirstPrint
    Credential = Pos::FirstPrint::Credential

    def self.call(gift_card)
      new(gift_card).call
    end

    def initialize(gift_card)
      @gift_card = gift_card
    end

    def call
      return [] unless @gift_card.gift_card_program.system_generated?

      credentials = []
      GiftCard.transaction do
        card = GiftCard.lock.find(@gift_card.id)
        if PosGiftCardCredentialDelivery.exists?(gift_card_id: card.id)
          return []
        end

        credentials = [
          Credential.new(
            kind: "replacement",
            masked_number: card.masked_number,
            number: card.number,
            amount_cents: card.balance_cents,
            program_name: card.gift_card_program.name
          )
        ]
        PosGiftCardCredentialDelivery.create!(
          gift_card: card,
          delivered_at: Time.current
        )
      end
      credentials
    end
  end
end
