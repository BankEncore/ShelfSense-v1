# frozen_string_literal: true

require "test_helper"

module GiftCards
  class ReplacementFirstPrintTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      GiftCards::Programs.seed!
      @program = GiftCardProgram.find_by!(code: "generated")
    end

    test "prints the new number once and does not reveal the old number" do
      original = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
      GiftCards::Fund.call(gift_card: original, amount_cents: 400, store: @store, performed_by: @actor)
      old_number = original.number

      replacement = GiftCards::Replace.call(
        gift_card: original,
        performed_by: @actor,
        store: @store,
        source_id: original.id,
        idempotency_key: SecureRandom.uuid_v7,
        reason_code: "lost",
        reason_name_snapshot: "Lost card"
      )
      new_card = replacement.replacement_gift_card

      credentials = GiftCards::ReplacementFirstPrint.call(new_card)
      assert_equal 1, credentials.size
      assert_equal new_card.number, credentials.first.number
      refute_equal old_number, credentials.first.number
      assert_equal [], GiftCards::ReplacementFirstPrint.call(new_card)
      assert PosGiftCardCredentialDelivery.exists?(gift_card_id: new_card.id)
    end
  end
end
