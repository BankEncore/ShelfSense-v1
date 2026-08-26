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
      return [] unless GiftCardReplacement.exists?(replacement_gift_card_id: @gift_card.id)

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
            number_prefix: card.number_prefix,
            amount_cents: card.balance_cents,
            program_name: card.gift_card_program.name,
            store: card.activated_store,
            issued_at: card.activated_at
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
