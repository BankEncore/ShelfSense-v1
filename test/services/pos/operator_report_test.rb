# frozen_string_literal: true

require "test_helper"

module Pos
  class OperatorReportTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      Cash::ActivityReasons.seed!
      @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
      @session = @context[:session]
      @period = @context[:period]
    end

    test "live X labels gross sales and omits trade credit" do
      groups = Pos::OperatorReport.session(
        totals: Pos::SessionTotals.for(@session),
        session: @session,
        kind: :x,
        include_expected_cash: true
      )
      sales = groups.find { |group| group.title == "Sales" }
      assert sales.rows.any? { |row| row.label == "Gross sales" }
      assert sales.rows.none? { |row| row.label == "Sales subtotal" }

      stored = groups.find { |group| group.title == "Stored value" }
      assert stored.rows.none? { |row| row.label.include?("Trade-credit") }
    end

    test "live X includes operational cash components and expected cash when gated on" do
      Cash::PaidIn.call(
        session: @session,
        actor: @actor,
        amount_cents: 500,
        reason_code: "paid_in_found",
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      groups = Pos::OperatorReport.session(
        totals: Pos::SessionTotals.for(@session.reload),
        session: @session,
        kind: :x,
        include_expected_cash: true
      )
      cash = groups.find { |group| group.title == "Cash custody" }
      assert_equal 500, cash.rows.find { |row| row.label == "Paid-in" }.cents
      assert cash.rows.any? { |row| row.label == "Expected Cash" }

      gated = Pos::OperatorReport.session(
        totals: Pos::SessionTotals.for(@session),
        session: @session,
        kind: :x,
        include_expected_cash: false
      ).find { |group| group.title == "Cash custody" }
      assert gated.rows.none? { |row| row.label == "Expected Cash" }
    end

    test "finalized Z omits fine stored-value rows and operational components without live query" do
      pos_close_session!(
        session: @session,
        actor: @actor,
        closing_count_cents: 10_000
      )
      period = Pos::FinalizeReportingPeriod.call(
        period: @period.reload,
        actor: @actor,
        expected_lock_version: @period.lock_version
      )

      groups = Pos::OperatorReport.period(period: period)
      stored = groups.find { |group| group.title == "Stored value" }
      labels = stored.rows.map(&:label)
      assert_includes labels, "Gift-card issuance"
      assert_includes labels, "Gift-card cash-outs"
      assert_not_includes labels, "Store-credit payments"
      assert_not_includes labels, "Gift-card payments"
      assert_not_includes labels, "Refund to original gift card"
      assert stored.rows.none? { |row| row.format == :count && row.label == "Gift-card cash-outs" }

      cash = groups.find { |group| group.title == "Cash custody" }
      assert cash.rows.none? { |row| row.label == "Paid-in" }
      assert cash.rows.none? { |row| row.label == "Drops" }
    end

    test "current open Z includes fine stored-value availability and components" do
      groups = Pos::OperatorReport.period(period: @period)
      stored = groups.find { |group| group.title == "Stored value" }
      assert stored.rows.any? { |row| row.label == "Store-credit payments" }

      cash = groups.find { |group| group.title == "Cash custody" }
      assert cash.rows.any? { |row| row.label == "Paid-in" }
    end

    test "PeriodTotals refuses live-only metrics after finalize" do
      pos_close_session!(
        session: @session,
        actor: @actor,
        closing_count_cents: 10_000
      )
      period = Pos::FinalizeReportingPeriod.call(
        period: @period.reload,
        actor: @actor,
        expected_lock_version: @period.lock_version
      )
      totals = Pos::PeriodTotals.for(period)

      assert_raises(ArgumentError) { totals.gift_card_cash_out_count }
      assert_raises(ArgumentError) { totals.store_credit_payment_cents }
      assert_raises(ArgumentError) { totals.paid_in_cents }
    end
    test "closed session gates expected cash and variance" do
      pos_close_session!(
        session: @session,
        actor: @actor,
        closing_count_cents: 10_000
      )
      totals = Pos::SessionTotals.for(@session.reload)

      gated = Pos::OperatorReport.session(
        totals: totals,
        session: @session,
        kind: :session,
        include_expected_cash: false
      ).find { |group| group.title == "Cash custody" }
      labels = gated.rows.map(&:label)
      assert_includes labels, "Counted Cash"
      assert_not_includes labels, "Expected closing Cash"
      assert_not_includes labels, "Variance"

      allowed = Pos::OperatorReport.session(
        totals: totals,
        session: @session,
        kind: :session,
        include_expected_cash: true
      ).find { |group| group.title == "Cash custody" }
      assert allowed.rows.any? { |row| row.label == "Expected closing Cash" }
      assert allowed.rows.any? { |row| row.label == "Variance" }
    end
  end
end
