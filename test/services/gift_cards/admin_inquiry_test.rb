# frozen_string_literal: true

require "test_helper"

module GiftCards
  class AdminInquiryTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      GiftCards::Programs.seed!
      @program = GiftCardProgram.find_by!(code: "generated")
    end

    test "unique prefix and last four opens the card and POS lookup stays digest-only" do
      card = numbered_card(last_four: "4242")
      GiftCards::Fund.call(gift_card: card, amount_cents: 250, store: @store, performed_by: @actor)

      result = GiftCards::AdminInquiry.call(
        prefix: card.number_prefix,
        last_four: "4242",
        actor: @actor,
        store: @store
      )
      assert_equal :found, result.status
      assert_equal card.id, result.card.id

      assert_nil GiftCards::Lookup.by_number("#{card.number_prefix}4242")
      assert_nil GiftCards::Lookup.by_number("4242")
      assert_equal card.id, GiftCards::Lookup.by_number(card.number).id
    end

    test "collisions return a masked candidate list without full numbers" do
      first = numbered_card(last_four: "7777")
      second = numbered_card(last_four: "7777")
      GiftCards::Fund.call(gift_card: first, amount_cents: 100, store: @store, performed_by: @actor)
      GiftCards::Fund.call(gift_card: second, amount_cents: 200, store: @store, performed_by: @actor)

      result = GiftCards::AdminInquiry.call(
        prefix: first.number_prefix,
        last_four: "7777",
        actor: @actor,
        store: @store
      )
      assert_equal :ambiguous, result.status
      assert_equal 2, result.candidates.size
      masked = result.candidates.map(&:masked_number)
      assert_includes masked, first.masked_number
      assert_includes masked, second.masked_number
      refute_includes result.candidates.map(&:inspect).join, first.number
      event = AuditEvent.where(action: "gift_cards.inquiry", outcome: "succeeded").order(:created_at).last
      refute_includes event.attributes.to_json, first.number
      refute_includes event.after_values.to_s, first.number
    end

    test "zero matches and submitted digits stay out of the audit" do
      result = GiftCards::AdminInquiry.call(
        prefix: "801",
        last_four: "0001",
        actor: @actor,
        store: @store
      )
      assert_equal :not_found, result.status
      event = AuditEvent.where(action: "gift_cards.inquiry", outcome: "failed").order(:created_at).last
      refute_includes event.attributes.to_json, "0001"
      refute_includes event.attributes.to_json, "801"
    end

    test "throttle matches resolver after repeated failures" do
      GiftCards::Resolver::FAILURE_LIMIT.times do
        GiftCards::AdminInquiry.call(prefix: "801", last_four: "0002", actor: @actor, store: @store)
      end
      error = assert_raises(GiftCards::Error) do
        GiftCards::AdminInquiry.call(prefix: "801", last_four: "0002", actor: @actor, store: @store)
      end
      assert_equal GiftCards::GENERIC_INQUIRY_FAILURE, error.message
    end

    private

    def numbered_card(last_four:)
      prefix = @program.prefix
      body_length = @program.number_length - prefix.length - 1
      50_000.times do |index|
        body = format("%0#{body_length}d", index)
        number = "#{prefix}#{body}#{GiftCards::Luhn.check_digit("#{prefix}#{body}")}"
        next unless number.end_with?(last_four)
        next if GiftCard.exists?(number_digest: GiftCards::Number.digest(number))

        return GiftCards::ProvisionInstrument.call(program: @program, store: @store, number: number)
      end
      raise "unable to allocate a #{prefix} number ending in #{last_four}"
    end
  end
end
