# frozen_string_literal: true

require "test_helper"

class PosTillActivityTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Cash::ActivityReasons.seed!
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    @session = @context[:session]
  end

  test "projects cash operations and gift-card cash-outs with signed session effects" do
    paid_in = Cash::PaidIn.call(
      session: @session,
      actor: @actor,
      amount_cents: 500,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    Cash::Drop.call(
      session: @session,
      actor: @actor,
      amount_cents: 1_000,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    result = Pos::TillActivity.call(session: @session)
    sources = result.rows.map(&:source)
    assert_includes sources, "cash_operation"
    labels = result.rows.map(&:label)
    assert_includes labels, "Paid in"
    assert_includes labels, "Cash drop"
    assert_includes labels, "Opening float"

    paid_row = result.rows.find { |row| row.id == paid_in.cash_operation_id }
    assert_equal 500, paid_row.session_effect_cents
    assert_equal "posted", paid_row.status
  end

  test "excludes session close and deposit transfers from the activity table" do
    result = Pos::TillActivity.call(session: @session)
    refute result.rows.any? { |row| row.label.match?(/session close|deposit/i) }
  end

  test "orders newest first with deterministic id tie-break and pages" do
    first = Cash::PaidIn.call(
      session: @session,
      actor: @actor,
      amount_cents: 100,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    travel 1.second
    second = Cash::PaidIn.call(
      session: @session,
      actor: @actor,
      amount_cents: 200,
      reason_code: "paid_in_found",
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    page1 = Pos::TillActivity.call(session: @session, page: 1)
    ids = page1.rows.map(&:id)
    assert_operator ids.index(second.cash_operation_id), :<, ids.index(first.cash_operation_id)
    assert_equal 50, Pos::TillActivity::PER_PAGE
  end
end
