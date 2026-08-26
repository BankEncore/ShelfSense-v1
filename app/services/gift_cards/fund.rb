# frozen_string_literal: true

module GiftCards
  class Fund
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(gift_card:, amount_cents:, store:, performed_by:, source_id: nil, idempotency_key: nil)
      @gift_card = gift_card
      @amount_cents = amount_cents
      @store = store
      @performed_by = performed_by
      @source_id = source_id || gift_card.id
      @idempotency_key = idempotency_key || SecureRandom.uuid_v7
    end

    def call
      raise GiftCards::Error, "amount must be positive" unless Integer(@amount_cents).positive?

      StoredValue::Post.call(
        operation_type: "activate",
        store: @store,
        performed_by: @performed_by,
        source_id: @source_id,
        idempotency_key: @idempotency_key,
        entries: [ { account: @gift_card.stored_value_account, amount_cents: Integer(@amount_cents) } ]
      )
      @gift_card.reload
    end
  end
end
