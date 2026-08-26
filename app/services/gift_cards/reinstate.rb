# frozen_string_literal: true

module GiftCards
  class Reinstate
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(gift_card:, actor:, store: nil, expected_lock_version: nil)
      @gift_card = gift_card
      @actor = actor
      @store = store
      @expected_lock_version = expected_lock_version
    end

    def call
      GiftCard.transaction do
        card = GiftCard.lock.find(@gift_card.id)
        raise GiftCards::Error, "only suspended gift cards can be reinstated" unless card.suspended?
        assert_lock!(card)
        account = StoredValueAccount.lock.find(card.stored_value_account_id)
        card.update!(status: "active")
        account.update!(status: "active") unless account.active?
        Audit::Recorder.record!(
          action: "gift_cards.reinstate",
          outcome: "succeeded",
          actor_user: @actor,
          store: @store,
          subject: card,
          after_values: { status: "active", number_last_four: card.number_last_four }
        )
        card
      end
    end

    private

    def assert_lock!(card)
      return if @expected_lock_version.blank?
      raise ActiveRecord::StaleObjectError.new(card, "reinstate") if card.lock_version != @expected_lock_version.to_i
    end
  end
end
