# frozen_string_literal: true

require "test_helper"

class AdminCashSafesTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @admin = @bootstrap[:administrator]
  end

  test "initialized store safe shows the expected balance" do
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get admin_cash_safe_path
    assert_response :success
    assert_match(/Expected balance/, response.body)
    get new_admin_cash_safe_path
    assert_redirected_to admin_cash_safe_path
  end

  test "initializes an uninitialized store safe with a distinct approver" do
    store = Store.create!(
      store_number: 41,
      code: "safeinit",
      name: "Safe Init",
      legal_name: "Safe Init LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    approver = cash_distinct_approver(store: store, assigned_by: @admin)

    sign_in_as("admin")
    post store_selection_path, params: { store_id: store.id }

    get new_admin_cash_safe_path
    assert_response :success

    post admin_cash_safe_path, params: {
      count: "250.00",
      notes: "Opening fund",
      approver_username: approver.username,
      approver_password: "correct-horse-battery"
    }
    assert_redirected_to admin_cash_safe_path
    safe = Cash::Locations.safe_for!(store)
    assert safe.initialized?
    assert_equal 25_000, safe.expected_balance_cents
  end

  test "refuses to initialize the safe as the same user" do
    store = Store.create!(
      store_number: 42,
      code: "safeself",
      name: "Safe Self",
      legal_name: "Safe Self LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    sign_in_as("admin")
    post store_selection_path, params: { store_id: store.id }
    post admin_cash_safe_path, params: {
      count: "10.00",
      approver_username: "admin",
      approver_password: "correct-horse-battery"
    }
    assert_response :unprocessable_content
    refute Cash::Locations.safe_for!(store).initialized?
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
