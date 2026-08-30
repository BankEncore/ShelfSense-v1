# frozen_string_literal: true

require "test_helper"

class PosStoredValueAdminInquiryRestoreTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    GiftCards::Programs.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
  end

  test "returns denied without loading cards when gift_cards.view is missing" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "restore_clerk")
    card = numbered_card(last_four: "1111")

    result = Pos::StoredValueAdminInquiryRestore.call(
      payload: { "admin_gift_card_id" => card.id },
      actor: clerk,
      store: @store
    )

    assert result.denied
    assert_nil result.card
    assert_empty result.candidates
  end

  test "returns denied for store context without gift_cards.view" do
    east = Store.create!(
      store_number: "9",
      code: "east_restore",
      name: "East Restore",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    manager = pos_store_manager(store: @store, assigned_by: @actor, username: "restore_mgr")
    card = numbered_card(last_four: "3333")

    result = Pos::StoredValueAdminInquiryRestore.call(
      payload: { "admin_candidate_ids" => [ card.id ] },
      actor: manager,
      store: east
    )

    assert result.denied
    assert_nil result.card
    assert_empty result.candidates
  end

  test "restores masked candidates when authorized" do
    first = numbered_card(last_four: "2222")
    second = numbered_card(last_four: "2222")

    result = Pos::StoredValueAdminInquiryRestore.call(
      payload: { "admin_candidate_ids" => [ first.id, second.id ] },
      actor: @actor,
      store: @store
    )

    refute result.denied
    assert_nil result.card
    assert_equal 2, result.candidates.size
    assert_equal [ first.masked_number, second.masked_number ], result.candidates.map(&:masked_number)
  end

  test "ignores blank admin payload" do
    result = Pos::StoredValueAdminInquiryRestore.call(
      payload: { "exact_gift_card_id" => SecureRandom.uuid_v7 },
      actor: @actor,
      store: @store
    )

    refute result.denied
    assert_nil result.card
    assert_empty result.candidates
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
