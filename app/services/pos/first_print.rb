# frozen_string_literal: true

module Pos
  class FirstPrint
    Credential = Struct.new(
      :kind, :masked_number, :number, :number_prefix, :amount_cents, :program_name, :store, :issued_at,
      keyword_init: true
    ) do
      def presented_number
        GiftCards::Number.present(number, prefix: number_prefix)
      end

      def legal_name
        store&.legal_name
      end

      def address_lines
        return [] if store.blank?

        lines = []
        lines << store.street_address_1.presence
        lines << store.street_address_2.presence
        locality = [ store.city.presence, store.region_code.presence ].compact.join(", ")
        locality = [ locality.presence, store.postal_code.presence ].compact.join(" ")
        lines << locality.presence
        lines << store.phone.presence
        lines.compact
      end

      def issued_at_label
        return if issued_at.blank? || store.blank?

        zone = ActiveSupport::TimeZone[store.timezone] || ActiveSupport::TimeZone["UTC"]
        issued_at.in_time_zone(zone).strftime("%-d %b %y %-l:%M%P")
      end
    end

    def self.call(transaction)
      new(transaction).call
    end

    def initialize(transaction)
      @transaction = transaction
    end

    def call
      credentials = []
      PosTransaction.transaction do
        PosTransaction.lock.find(@transaction.id)
        if PosGiftCardCredentialDelivery.exists?(pos_transaction_id: @transaction.id)
          return []
        end
        session = PosSession.lock.find(@transaction.pos_session_id)
        return [] unless session.open?

        credentials = decrypt_undelivered_credentials
        if credentials.any?
          PosGiftCardCredentialDelivery.create!(
            pos_transaction: @transaction,
            delivered_at: Time.current
          )
        end
      end
      credentials
    end

    private

    def decrypt_undelivered_credentials
      credentials = []
      @transaction.pos_stored_value_issuances.ordered.each do |issuance|
        next unless issuance.activation? && issuance.system_generated?

        card = issuance.gift_card
        next if card.blank?

        credentials << credential_for(card, kind: issuance.issuance_type, amount_cents: issuance.amount_cents)
      end
      @transaction.pos_tenders.ordered.each do |tender|
        detail = tender.stored_value_tender_detail
        next unless detail&.new_gift_card?

        card = detail.gift_card
        next unless card&.gift_card_program&.system_generated?

        credentials << credential_for(card, kind: "refund_gift_card", amount_cents: tender.amount_cents)
      end
      credentials
    end

    def credential_for(card, kind:, amount_cents:)
      Credential.new(
        kind: kind,
        masked_number: card.masked_number,
        number: card.number,
        number_prefix: card.number_prefix,
        amount_cents: amount_cents,
        program_name: card.gift_card_program.name,
        store: @transaction.store,
        issued_at: @transaction.completed_at
      )
    end
  end
end
