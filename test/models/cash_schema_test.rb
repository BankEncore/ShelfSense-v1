# frozen_string_literal: true

require "test_helper"

class CashSchemaTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
  end

  test "session close snapshots may be historically negative without a cash entry" do
    register = Register.create!(store: @store, register_number: 9, name: "Legacy")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)
    session = PosSession.create!(
      store: @store,
      register: register,
      reporting_period: period,
      cashier_user: @actor,
      status: "closed",
      opened_at: Time.current,
      closed_at: Time.current,
      opening_float_cents: 0,
      closing_expected_cash_cents: -500,
      closing_count_cents: 0,
      closing_variance_cents: 500
    )

    assert_equal(-500, session.closing_expected_cash_cents)
    assert_equal 0, session.cash_entries.count
  end

  test "cash entries reject a zero amount" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 100)
    operation = CashOperation.create!(
      operation_type: "paid_in",
      store: @store,
      business_date: Date.current,
      occurred_at: Time.current,
      performed_by: @actor,
      pos_session: context[:session],
      idempotency_operation: IdempotencyOperation.create!(
        source_id: SecureRandom.uuid_v7,
        operation_type: "cash_post",
        idempotency_key: SecureRandom.uuid_v7,
        payload_hash: "x",
        status: "completed"
      )
    )

    error = assert_raises(ActiveRecord::RecordInvalid) do
      CashEntry.create!(
        cash_operation: operation,
        entry_sequence: 0,
        amount_cents: 0,
        balance_after_cents: 0,
        pos_session: context[:session]
      )
    end
    assert_match(/Amount cents/, error.message)
  end

  test "safe initialization is unique per location" do
    store = Store.create!(
      store_number: 77,
      code: "once",
      name: "Once",
      legal_name: "Once LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    Cash::InitializeSafe.call(
      store: store,
      performed_by: @actor,
      approved_by: cash_distinct_approver(store: store, assigned_by: @actor),
      count_cents: 10,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    error = assert_raises(Cash::Error) do
      Cash::InitializeSafe.call(
        store: store,
        performed_by: @actor,
        approved_by: cash_distinct_approver(store: store, assigned_by: @actor),
        count_cents: 10,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/already initialized/, error.message)
  end

  test "superseded_count_id is unique when present" do
    safe = Cash::Locations.safe_for!(@store)
    start_count = Cash::SnapshotCount.start!(location: safe, purpose: "safe_reconciliation")
    Cash::SnapshotCount.accept!(count: start_count, total_cents: start_count.expected_cents_snapshot)

    assert_raises(ActiveRecord::RecordNotUnique) do
      CashCount.insert!(
        {
          id: SecureRandom.uuid_v7,
          purpose: "safe_reconciliation",
          total_cents: start_count.expected_cents_snapshot,
          status: "accepted",
          superseded_count_id: start_count.id,
          cash_location_id: safe.id,
          created_at: Time.current
        }
      )
    end
  end

  test "cash entries reject a location from another store" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 100)
    other = Store.create!(
      store_number: 81,
      code: "other-cash",
      name: "Other Cash",
      legal_name: "Other Cash LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    operation = CashOperation.create!(
      operation_type: "paid_in",
      store: @store,
      business_date: Date.current,
      occurred_at: Time.current,
      performed_by: @actor,
      pos_session: context[:session],
      idempotency_operation: IdempotencyOperation.create!(
        source_id: SecureRandom.uuid_v7,
        operation_type: "cash_post",
        idempotency_key: SecureRandom.uuid_v7,
        payload_hash: "x",
        status: "completed"
      )
    )

    error = assert_raises(ActiveRecord::RecordInvalid) do
      CashEntry.create!(
        cash_operation: operation,
        entry_sequence: 0,
        amount_cents: 1,
        balance_after_cents: 1,
        cash_location: Cash::Locations.safe_for!(other)
      )
    end
    assert_match(/must belong to the operation store/, error.message)
  end

  test "cash operations reject a session from another store" do
    other = Store.create!(
      store_number: 82,
      code: "other-session",
      name: "Other Session",
      legal_name: "Other Session LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    foreign_session = pos_open_context(store: other, actor: @actor, opening_float_cents: 0)[:session]

    error = assert_raises(ActiveRecord::RecordInvalid) do
      CashOperation.create!(
        operation_type: "paid_in",
        store: @store,
        business_date: Date.current,
        occurred_at: Time.current,
        performed_by: @actor,
        pos_session: foreign_session,
        idempotency_operation: IdempotencyOperation.create!(
          source_id: SecureRandom.uuid_v7,
          operation_type: "cash_post",
          idempotency_key: SecureRandom.uuid_v7,
          payload_hash: "x",
          status: "completed"
        )
      )
    end
    assert_match(/must belong to the operation store/, error.message)
  end
end
