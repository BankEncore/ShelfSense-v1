# frozen_string_literal: true

require "test_helper"

class PosCashActivitiesTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Cash::ActivityReasons.seed!
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    sign_in_as("admin")
  end

  test "cashier records a paid-in from Register" do
    get pos_path
    assert_response :success
    assert_includes response.body, new_pos_cash_paid_in_path

    post pos_cash_paid_ins_path, params: {
      amount: "5.00",
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to pos_path
    assert_equal 500, CashPaidIn.last.amount_cents
  end

  test "cashier records a drop from the session to the safe" do
    post pos_cash_drops_path, params: {
      amount: "20.00",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to pos_path
    assert_equal "drop", CashTransfer.order(:created_at).last.transfer_type
  end

  test "manager replenishes an open session from the safe" do
    post pos_cash_replenishments_path, params: {
      pos_session_id: @context[:session].id,
      amount: "10.00",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to pos_path
    assert_equal "replenishment", CashTransfer.order(:created_at).last.transfer_type
  end

  test "manager reverses a paid-in without fabricating a source row" do
    paid_in = Cash::PaidIn.call(
      session: @context[:session],
      actor: @actor,
      amount_cents: 250,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    post pos_cash_reversals_path, params: {
      cash_operation_id: paid_in.cash_operation_id,
      reason_code: "reverse",
      notes: "Wrong amount",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to pos_path
    reverse = CashOperation.find_by!(reversal_of_id: paid_in.cash_operation_id)
    assert_equal "reverse", reverse.operation_type
    assert_nil reverse.cash_paid_in
  end

  test "associate does not see paid-in and cannot post one" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "till_clerk")
    pos_open_context(
      store: @store,
      actor: clerk,
      register: Register.create!(store: @store, register_number: 15, name: "Clerk till"),
      opening_float_cents: 10_000
    )
    delete session_path
    sign_in_as("till_clerk")

    get pos_path
    assert_response :success
    refute_includes response.body, new_pos_cash_paid_in_path
    assert_includes response.body, new_pos_cash_drop_path

    post pos_cash_paid_ins_path, params: {
      amount: "1.00",
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to pos_path
    assert_equal 0, CashPaidIn.count
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
