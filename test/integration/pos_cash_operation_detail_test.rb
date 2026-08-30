# frozen_string_literal: true

require "test_helper"

class PosCashOperationDetailTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Cash::ActivityReasons.seed!
    @register = Register.create!(store: @store, register_number: 31, name: "Detail")
    @context = pos_open_context(store: @store, actor: @actor, register: @register, opening_float_cents: 10_000)
    @paid_in = Cash::PaidIn.call(
      session: @context[:session],
      actor: @actor,
      amount_cents: 400,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    @operation = @paid_in.cash_operation
    sign_in_as("admin")
  end

  test "GET detail does not seed reasons or mutate cash or session state" do
    reason_count = CashActivityReason.count
    reason_digest = CashActivityReason.order(:id).pluck(:id, :updated_at, :name)
    operation_count = CashOperation.count
    entry_count = CashEntry.count
    session_lock = @context[:session].lock_version
    working = Pos::StartTransaction.call(session: @context[:session], actor: @actor)

    get pos_cash_operation_path(@operation, register_id: @register.id)
    assert_response :success
    assert_select "[data-controller='pos-blocking-overlay']"
    assert_select "#pos_cash_reversal_overlay[data-register-blocking-overlay]"

    assert_equal reason_count, CashActivityReason.count
    assert_equal reason_digest, CashActivityReason.order(:id).pluck(:id, :updated_at, :name)
    assert_equal operation_count, CashOperation.count
    assert_equal entry_count, CashEntry.count
    assert_equal session_lock, @context[:session].reload.lock_version
    assert_equal @operation.id, @operation.reload.id
    assert working.reload.working?
  end

  test "nested reversal posts through Cash::Reverse and rejects reverse-of-reverse" do
    post reversal_pos_cash_operation_path(@operation), params: {
      reason_code: "reverse",
      notes: "Wrong amount",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      register_id: @register.id
    }
    assert_redirected_to pos_cash_operation_path(@operation, register_id: @register.id)
    reverse = CashOperation.find_by!(reversal_of_id: @operation.id)
    assert_equal "reverse", reverse.operation_type
    assert @operation.reload.reversed?

    post reversal_pos_cash_operation_path(reverse), params: {
      reason_code: "reverse",
      notes: "Nope",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      register_id: @register.id
    }
    assert_redirected_to pos_cash_operation_path(reverse, register_id: @register.id)
    follow_redirect!
    assert_match(/cannot be reversed/i, flash[:alert].to_s + response.body)
  end

  test "already reversed original cannot be reversed again" do
    Cash::Reverse.call(
      operation: @operation,
      actor: @actor,
      reason_code: "reverse",
      notes: "Once",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    post reversal_pos_cash_operation_path(@operation), params: {
      reason_code: "reverse",
      notes: "Twice",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      register_id: @register.id
    }
    assert_redirected_to pos_cash_operation_path(@operation, register_id: @register.id)
    assert_equal 1, CashOperation.where(reversal_of_id: @operation.id).count
  end

  test "unsupported opening float cannot be reversed from detail" do
    float_op = CashOperation.joins(:cash_transfer)
                            .where(pos_session_id: @context[:session].id, cash_transfers: { transfer_type: "opening_float" })
                            .first!
    get pos_cash_operation_path(float_op, register_id: @register.id)
    assert_response :success
    assert_select "#pos_cash_reversal_overlay", count: 0

    post reversal_pos_cash_operation_path(float_op), params: {
      reason_code: "reverse",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      register_id: @register.id
    }
    assert_redirected_to pos_cash_operation_path(float_op, register_id: @register.id)
  end

  test "generic cash reversals launcher is gone" do
    assert_raises(NameError) { pos_cash_reversals_path }
    get "/pos/cash_reversals/new"
    assert_response :not_found
  end

  test "blank notes on reverse reason leaves the original posted" do
    post reversal_pos_cash_operation_path(@operation), params: {
      reason_code: "reverse",
      notes: "",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      register_id: @register.id
    }
    assert_response :unprocessable_content
    refute @operation.reload.reversed?
    assert_equal 0, CashOperation.where(reversal_of_id: @operation.id).count
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
