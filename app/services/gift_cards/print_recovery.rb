# frozen_string_literal: true

module GiftCards
  class PrintRecovery
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(gift_card:, actor:, store:, reason:)
      @gift_card = gift_card
      @actor = actor
      @store = store
      @reason = reason.to_s.strip
    end

    def call
      raise GiftCards::Error, "a recovery reason is required" if @reason.blank?
      unless @gift_card.gift_card_program.system_generated?
        raise GiftCards::Error, "print recovery applies only to system-generated cards"
      end
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor,
        permission_key: "gift_cards.view",
        store: @store
      )
        raise GiftCards::Error, "not authorized to recover a gift-card print"
      end

      Audit::Recorder.record!(
        action: "gift_cards.print_recovery",
        outcome: "succeeded",
        actor_user: @actor,
        store: @store,
        subject: @gift_card,
        reason_text: @reason,
        after_values: {
          gift_card_id: @gift_card.id,
          number_last_four: @gift_card.number_last_four
        }
      )
      @gift_card.number
    end
  end
end
