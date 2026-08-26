# frozen_string_literal: true

module GiftCards
  class AdminInquiry
    Result = Data.define(:status, :card, :candidates)

    Candidate = Data.define(
      :id, :masked_number, :status, :program_name, :balance_cents, :activated_at
    )

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(prefix:, last_four:, actor:, store: nil)
      @prefix = prefix.to_s.strip
      @last_four = last_four.to_s.strip
      @actor = actor
      @store = store
    end

    def call
      enforce_throttle!
      unless valid_fragments?
        record_failure!
        return Result.new(status: :not_found, card: nil, candidates: [])
      end

      cards = GiftCard.where(number_prefix: @prefix, number_last_four: @last_four)
                      .includes(:gift_card_program, :stored_value_account)
                      .admin_ordered
                      .to_a

      case cards.size
      when 0
        record_failure!
        Result.new(status: :not_found, card: nil, candidates: [])
      when 1
        card = cards.first
        record_success!(card, extra: { number_last_four: card.number_last_four, status: card.status })
        Result.new(status: :found, card: card, candidates: [])
      else
        candidates = cards.map { |card| candidate_for(card) }
        record_success!(
          nil,
          extra: {
            match_count: cards.size,
            gift_card_ids: cards.map(&:id),
            number_last_four: @last_four
          }
        )
        Result.new(status: :ambiguous, card: nil, candidates: candidates)
      end
    end

    private

    def valid_fragments?
      @prefix.match?(/\A\d+\z/) && @last_four.match?(/\A\d{4}\z/)
    end

    def candidate_for(card)
      Candidate.new(
        id: card.id,
        masked_number: card.masked_number,
        status: card.status,
        program_name: card.gift_card_program.name,
        balance_cents: card.balance_cents,
        activated_at: card.activated_at
      )
    end

    def enforce_throttle!
      failures = AuditEvent.where(action: "gift_cards.inquiry", outcome: "failed", actor_user_id: @actor&.id)
                           .where("occurred_at > ?", GiftCards::Resolver::FAILURE_WINDOW.ago)
                           .count
      return if failures < GiftCards::Resolver::FAILURE_LIMIT

      raise GiftCards::Error, GENERIC_INQUIRY_FAILURE
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

    def record_success!(card, extra:)
      Audit::Recorder.record!(
        action: "gift_cards.inquiry",
        outcome: "succeeded",
        actor_user: @actor,
        store: @store,
        subject: card,
        after_values: extra
      )
    end
  end
end
