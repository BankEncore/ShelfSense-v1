# frozen_string_literal: true

require "test_helper"

class PosStoredValueInquiryTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    GiftCards::Programs.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    sign_in_as("admin")
  end

  test "show renders three labeled paths inside the shell without creating a session" do
    get pos_stored_value_inquiry_path, params: { register_id: @register.id }
    assert_response :success
    assert_select ".pos-register-shell"
    assert_select "h1", text: "Stored Value Inquiry"
    assert_select "h2", text: /complete gift-card number/i
    assert_select "h2", text: /store credit/i
    assert_select "h2", text: /prefix and last four/i
    assert_select "form[action='#{exact_number_pos_stored_value_inquiry_path}'][method='post']"
    assert_select "form[action='#{store_credit_pos_stored_value_inquiry_path}'][method='post']"
    assert_select "form[action='#{admin_prefix_last_four_pos_stored_value_inquiry_path}'][method='post']"
    refute PosSession.open.exists?
  end

  test "exact number POST redirects then shows masked balance and never echoes the full number" do
    card = numbered_card(last_four: "4242")
    GiftCards::Fund.call(gift_card: card, amount_cents: 1_800, store: @store, performed_by: @actor)

    post exact_number_pos_stored_value_inquiry_path, params: {
      register_id: @register.id,
      card_number: card.number
    }
    assert_redirected_to pos_stored_value_inquiry_path(register_id: @register.id)
    follow_redirect!
    assert_response :success
    assert_select "#sv-inquiry-result"
    assert_match card.masked_number, response.body
    assert_match format_money_cents(1_800), response.body
    assert_match "Available balance", response.body
    refute_includes response.body, card.number
    refute_match(/card_number=#{Regexp.escape(card.number)}/, response.body)
    assert_select "a", text: "Use as Tender", count: 0
    assert_select "a", text: "Reload", count: 0
  end

  test "admin prefix path shows masked candidates without continuation actions" do
    first = numbered_card(last_four: "3131")
    second = numbered_card(last_four: "3131")
    GiftCards::Fund.call(gift_card: first, amount_cents: 100, store: @store, performed_by: @actor)
    GiftCards::Fund.call(gift_card: second, amount_cents: 200, store: @store, performed_by: @actor)

    post admin_prefix_last_four_pos_stored_value_inquiry_path, params: {
      register_id: @register.id,
      number_prefix: first.number_prefix,
      number_last_four: "3131"
    }
    assert_response :redirect
    follow_redirect!
    assert_match first.masked_number, response.body
    assert_match second.masked_number, response.body
    refute_includes response.body, first.number
    assert_select "a", text: "Use as Tender", count: 0
    assert_select "a", text: "Cash Out Eligible Balance", count: 0
    assert AuditEvent.exists?(action: "gift_cards.inquiry", outcome: "succeeded", actor_user: @actor)
  end

  test "admin path requires gift_cards.view" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "sv_clerk")
    delete session_path
    sign_in_as("sv_clerk")

    get pos_stored_value_inquiry_path
    assert_response :success
    assert_select "h2", text: /prefix and last four/i, count: 0

    post admin_prefix_last_four_pos_stored_value_inquiry_path, params: {
      number_prefix: "801",
      number_last_four: "0001"
    }
    assert_redirected_to pos_stored_value_inquiry_path
  end

  test "store credit path finds customer by identity without gift card lookup" do
    customer = Customer.create!(
      display_name: "Jane Inquiry",
      email: "jane.inquiry@example.com",
      phone: "555-0199"
    )
    account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: customer)
    reason = StoredValueAdjustmentReason.find_by!(code: "goodwill")
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: 500,
      reason: reason,
      store: @store,
      performed_by: @actor,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7
    )

    post store_credit_pos_stored_value_inquiry_path, params: {
      register_id: @register.id,
      customer_query: "Jane Inquiry"
    }
    assert_redirected_to pos_stored_value_inquiry_path(register_id: @register.id, customer_query: "Jane Inquiry")
    follow_redirect!
    assert_match "Jane Inquiry", response.body
    assert_select "#sv-inquiry-result"

    post store_credit_pos_stored_value_inquiry_path, params: {
      register_id: @register.id,
      customer_id: customer.id
    }
    assert_response :redirect
    follow_redirect!
    assert_match format_money_cents(500), response.body
    assert_match "Customer store credit", response.body
  end

  test "GET with card_number query does not perform possession lookup" do
    card = numbered_card(last_four: "9999")
    GiftCards::Fund.call(gift_card: card, amount_cents: 100, store: @store, performed_by: @actor)

    get pos_stored_value_inquiry_path, params: { card_number: card.number }
    assert_response :success
    refute_match card.masked_number, response.body
    refute_includes response.body, card.number
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def format_money_cents(cents)
    format("$%d.%02d", cents / 100, cents % 100)
  end

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
