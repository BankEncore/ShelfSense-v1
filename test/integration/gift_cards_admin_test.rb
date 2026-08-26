# frozen_string_literal: true

require "test_helper"

class GiftCardsAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    GiftCards::Programs.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
  end

  test "inquiry finds a masked card and never renders the full number" do
    number = GiftCards::Number.generate(@program)
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store, number: number)
    GiftCards::Fund.call(gift_card: card, amount_cents: 150, store: @store, performed_by: @admin)

    sign_in_as("admin")
    get inquiry_admin_gift_cards_path
    assert_response :success

    post inquiry_admin_gift_cards_path, params: { card_number: number }
    assert_redirected_to admin_gift_card_path(card)
    follow_redirect!
    assert_response :success
    assert_includes response.body, card.masked_number
    assert_not_includes response.body, number
    get admin_products_path
    assert_includes response.body, inquiry_admin_gift_cards_path
    assert_includes response.body, admin_gift_card_programs_path
  end

  test "associates cannot inquire gift cards" do
    associate = User.create!(
      username: "gc_associate",
      display_name: "GC Associate",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )
    sign_in_as("gc_associate")
    post store_selection_path, params: { store_id: @store.id }
    get inquiry_admin_gift_cards_path
    assert_redirected_to root_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
