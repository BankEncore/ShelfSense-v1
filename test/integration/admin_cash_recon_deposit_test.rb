# frozen_string_literal: true

require "test_helper"

class AdminCashReconDepositTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Cash::ActivityReasons.seed!
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }
  end

  test "manager accepts a zero-variance safe count from the admin screen" do
    safe = Cash::Locations.safe_for!(@store)
    get new_admin_cash_safe_reconciliation_path
    assert_response :success
    count_id = CashCount.where(purpose: "safe_reconciliation", status: "discarded").order(:created_at).last.id

    post admin_cash_safe_reconciliation_path, params: {
      cash_count_id: count_id,
      count: format("%.2f", safe.expected_balance_cents / 100.0),
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to admin_cash_safe_path
    assert CashCount.exists?(purpose: "safe_reconciliation", status: "accepted")
    assert_equal 0, CashReconciliation.where(cash_location: safe).count
  end

  test "manager prepares and reverses a deposit" do
    get new_admin_cash_deposit_path
    assert_response :success
    count_id = CashCount.where(purpose: "deposit", status: "discarded").order(:created_at).last.id

    post admin_cash_deposits_path, params: {
      cash_count_id: count_id,
      amount: "15.00",
      bag_reference: "A1",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    deposit = CashDeposit.last
    assert_redirected_to admin_cash_deposit_path(deposit)
    follow_redirect!
    assert_match(/In transit/, response.body)

    post reverse_admin_cash_deposit_path(deposit), params: {
      notes: "Still in the office",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to admin_cash_deposit_path(deposit)
    assert deposit.cash_operation.reload.reversed?
  end

  test "store-day report is not a close gate and lists deposits" do
    start_count = Cash::SnapshotCount.start!(
      location: Cash::Locations.safe_for!(@store),
      purpose: "deposit"
    )
    Cash::PrepareDeposit.call(
      store: @store,
      actor: @actor,
      start_count: start_count,
      amount_cents: 800,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    get admin_cash_store_day_path, params: { business_date: BusinessDate.for_store(@store).iso8601 }
    assert_response :success
    assert_match(/Store-day cash/, response.body)
    assert_match(/deposit prepared/, response.body)
    assert_match(/not a close gate/, response.body)
    assert_match(/\$8.00/, response.body)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
