# frozen_string_literal: true

module Pos
  class FirstPrint
    Credential = Struct.new(:kind, :masked_number, :number, :amount_cents, :program_name, keyword_init: true)

    def self.call(transaction)
      new(transaction).call
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      credentials = []
      @transaction.pos_stored_value_issuances.ordered.each do |issuance|
        next unless issuance.system_generated?
        card = issuance.gift_card
        next if card.blank?

        credentials << Credential.new(
          kind: issuance.issuance_type,
          masked_number: card.masked_number,
          number: card.number,
          amount_cents: issuance.amount_cents,
          program_name: card.gift_card_program.name
        )
      end
      @transaction.pos_tenders.ordered.each do |tender|
        detail = tender.stored_value_tender_detail
        next unless detail&.new_gift_card?

        card = detail.gift_card
        next unless card&.gift_card_program&.system_generated?

        credentials << Credential.new(
          kind: "refund_gift_card",
          masked_number: card.masked_number,
          number: card.number,
          amount_cents: tender.amount_cents,
          program_name: card.gift_card_program.name
        )
      end
      credentials
    end
  end
end
