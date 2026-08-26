# frozen_string_literal: true

module GiftCards
  class AssociateCustomer
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(gift_card:, actor:, customer: nil, store: nil, expected_lock_version: nil)
      @gift_card = gift_card
      @actor = actor
      @customer = customer
      @store = store
      @expected_lock_version = expected_lock_version
    end

    def call
      GiftCard.transaction do
        card = GiftCard.lock.find(@gift_card.id)
        raise GiftCards::Error, "replaced or closed cards cannot change association" if card.replaced? || card.closed?
        assert_lock!(card)
        before = card.customer_id
        card.update!(customer: @customer)
        Audit::Recorder.record!(
          action: "gift_cards.associate_customer",
          outcome: "succeeded",
          actor_user: @actor,
          store: @store,
          subject: card,
          before_values: { customer_id: before },
          after_values: { customer_id: card.customer_id, number_last_four: card.number_last_four }
        )
        card
      end
    end

    private

    def assert_lock!(card)
      return if @expected_lock_version.blank?
      raise ActiveRecord::StaleObjectError.new(card, "associate") if card.lock_version != @expected_lock_version.to_i
    end
  end
end
