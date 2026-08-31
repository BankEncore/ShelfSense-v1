# frozen_string_literal: true

module Pos
  # Restores masked admin inquiry results from a PRG flash payload.
  # Re-evaluates gift_cards.view for the current actor/store before loading cards.
  class StoredValueAdminInquiryRestore
    Result = Data.define(:card, :candidates, :denied)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(payload:, actor:, store:)
      @payload = payload || {}
      @actor = actor
      @store = store
    end

    def call
      return empty(denied: false) unless admin_payload?

      unless authorized?
        return empty(denied: true)
      end

      Result.new(card: load_card, candidates: load_candidates, denied: false)
    end

    private

    def admin_payload?
      @payload["admin_gift_card_id"].present? || Array(@payload["admin_candidate_ids"]).any?
    end

    def authorized?
      Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "gift_cards.view",
        store: @store
      )
    end

    def load_card
      id = @payload["admin_gift_card_id"]
      return nil if id.blank?

      GiftCard.includes(:gift_card_program, :stored_value_account).find_by(id: id)
    end

    def load_candidates
      ids = Array(@payload["admin_candidate_ids"])
      return [] if ids.empty?

      cards = GiftCard.includes(:gift_card_program, :stored_value_account)
                      .where(id: ids)
                      .index_by(&:id)
      ids.filter_map do |id|
        card = cards[id]
        next unless card

        GiftCards::AdminInquiry::Candidate.new(
          id: card.id,
          masked_number: card.masked_number,
          status: card.status,
          program_name: card.gift_card_program.name,
          balance_cents: card.balance_cents,
          activated_at: card.activated_at
        )
      end
    end

    def empty(denied:)
      Result.new(card: nil, candidates: [], denied: denied)
    end
  end
end
