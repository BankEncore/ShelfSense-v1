# frozen_string_literal: true

module GiftCards
  class Resolver
    FAILURE_WINDOW = 15.minutes
    FAILURE_LIMIT = 8

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(raw_number:, actor:, store: nil)
      @raw_number = raw_number
      @actor = actor
      @store = store
    end

    def call
      enforce_throttle!
      normalized = GiftCards::Number.normalize(@raw_number)
      card = lookup(normalized)
      unless card
        record_failure!
        raise GiftCards::Error, GENERIC_INQUIRY_FAILURE
      end

      card
    end

    private

    def lookup(normalized)
      return if normalized.blank?
      return unless normalized.match?(/\A\d+\z/)

      digest = GiftCards::Number.digest(normalized)
      GiftCard.find_by(number_digest: digest)
    end

    def enforce_throttle!
      failures = AuditEvent.where(action: "gift_cards.inquiry", outcome: "failed", actor_user_id: @actor&.id)
                           .where("occurred_at > ?", FAILURE_WINDOW.ago)
                           .count
      raise GiftCards::Error, GENERIC_INQUIRY_FAILURE if failures >= FAILURE_LIMIT
    end

    def record_failure!
      Audit::Recorder.record!(
        action: "gift_cards.inquiry",
        outcome: "failed",
        actor_user: @actor,
        store: @store,
        reason_text: GENERIC_INQUIRY_FAILURE
      )
    end
  end
end
