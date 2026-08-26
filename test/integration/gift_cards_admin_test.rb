# frozen_string_literal: true

require "test_helper"

class GiftCardsAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    GiftCards::Programs.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    sign_in_as("admin")
  end

  test "gift-card show lists masked activity after activate" do
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: 300, store: @store, performed_by: @admin)

    get admin_gift_card_path(card)
    assert_response :success
    assert_includes response.body, "Account activity"
    assert_includes response.body, "Activate"
    assert_includes response.body, card.masked_number
    refute_includes response.body, card.number
  end

  test "prefix last-four inquiry unique hit redirects and collisions stay masked" do
    first = numbered_card("3131")
    second = numbered_card("3131")
    GiftCards::Fund.call(gift_card: first, amount_cents: 100, store: @store, performed_by: @admin)

    post inquiry_admin_gift_cards_path, params: { number_prefix: first.number_prefix, number_last_four: "3131" }
    assert_response :unprocessable_entity
    assert_includes response.body, first.masked_number
    assert_includes response.body, second.masked_number
    refute_includes response.body, first.number
    refute_includes response.body, second.number

    unique = numbered_card("6262")
    post inquiry_admin_gift_cards_path, params: { number_prefix: unique.number_prefix, number_last_four: "6262" }
    assert_redirected_to admin_gift_card_path(unique)
  end

  test "exact inquiry still uses digest lookup" do
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    post inquiry_admin_gift_cards_path, params: { card_number: card.number }
    assert_redirected_to admin_gift_card_path(card)
  end

  test "system-generated replacement lands on a one-shot credential voucher" do
    original = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: original, amount_cents: 500, store: @store, performed_by: @admin)
    old_number = original.number

    post replace_admin_gift_card_path(original), params: {
      reason_code: "lost",
      notes: "print new card",
      idempotency_key: SecureRandom.uuid_v7
    }
    new_card = original.reload.replaced_by
    assert_redirected_to credential_admin_gift_card_path(new_card)
    follow_redirect!
    assert_includes response.body, new_card.number
    refute_includes response.body, old_number
    assert_match "Print gift card", response.body

    get credential_admin_gift_card_path(new_card)
    assert_redirected_to admin_gift_card_path(new_card)
    follow_redirect!
    refute_includes response.body, new_card.number
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def numbered_card(last_four)
    prefix = @program.prefix
    body_length = @program.number_length - prefix.length - 1
    50_000.times do |index|
      body = format("%0#{body_length}d", index)
      number = "#{prefix}#{body}#{GiftCards::Luhn.check_digit("#{prefix}#{body}")}"
      next unless number.end_with?(last_four)
      next if GiftCard.exists?(number_digest: GiftCards::Number.digest(number))

      return GiftCards::ProvisionInstrument.call(program: @program, store: @store, number: number)
    end
    raise "unable to allocate a number ending in #{last_four}"
  end
end
