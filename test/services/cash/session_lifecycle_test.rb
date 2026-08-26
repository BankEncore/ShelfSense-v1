# frozen_string_literal: true

require "test_helper"

module Cash
  class SessionLifecycleTest < ActiveSupport::TestCase
    setup do
      @bootstrap = bootstrap!
      @store = @bootstrap[:store]
      @actor = @bootstrap[:administrator]
      @approver = @bootstrap[:safe_approver]
      Cash::ActivityReasons.seed!
    end

    test "open posts a safe to session transfer for a positive float" do
      safe = Cash::Locations.safe_for!(@store)
      before = safe.expected_balance_cents
      context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 5000)

      assert_equal 5000, context[:session].opening_float_cents
      assert_equal before - 5000, safe.reload.expected_balance_cents
      transfer = CashTransfer.find_by!(transfer_type: "opening_float", destination_pos_session: context[:session])
      assert_equal 5000, transfer.amount_cents
    end

    test "zero float open creates no transfer" do
      pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)

      assert_equal 0, CashTransfer.where(transfer_type: "opening_float").count
    end

    test "open fails when the safe is not initialized" do
      other = Store.create!(
        store_number: 99,
        code: "uninit",
        name: "Uninit",
        legal_name: "Uninit LLC",
        timezone: "America/New_York",
        country_code: "US"
      )
      register = Register.create!(store: other, register_number: 1, name: "Front")
      period = Pos::OpenReportingPeriod.call(store: other, register: register, actor: @actor)

      error = assert_raises(Pos::Error) do
        Pos::OpenSession.call(
          store: other,
          register: register,
          actor: @actor,
          reporting_period: period,
          opening_float_cents: 0
        )
      end
      assert_match(/not initialized/, error.message)
    end

    test "close transfers counted cash and keeps pre-recon expected snapshot" do
      context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 5000)
      safe_before = Cash::Locations.safe_for!(@store).expected_balance_cents

      session = pos_close_session!(
        session: context[:session],
        actor: @actor,
        expected_lock_version: context[:session].lock_version,
        closing_count_cents: 4800,
        variance_reason_code: "short_count",
        variance_notes: "Short a couple of dollars"
      )

      assert_equal 5000, session.closing_expected_cash_cents
      assert_equal 4800, session.closing_count_cents
      assert_equal(-200, session.closing_variance_cents)
      assert_equal @actor.id, session.closed_by_user_id
      assert_equal 4800, Cash::Locations.safe_for!(@store).expected_balance_cents - safe_before
      assert_equal session.closing_expected_cash_cents, Pos::SessionTotals.for(session.reload).expected_cash_cents
    end

    test "safe initialization requires a distinct approver" do
      store = Store.create!(
        store_number: 88,
        code: "init2",
        name: "Init Two",
        legal_name: "Init Two LLC",
        timezone: "America/New_York",
        country_code: "US"
      )
      error = assert_raises(Cash::Error) do
        Cash::InitializeSafe.call(
          store: store,
          performed_by: @actor,
          approved_by: @actor,
          count_cents: 100,
          source_id: SecureRandom.uuid_v7,
          idempotency_key: SecureRandom.uuid_v7
        )
      end
      assert_match(/differ/, error.message)
    end

    test "zero count initialization posts no entries" do
      store = Store.create!(
        store_number: 87,
        code: "zeroinit",
        name: "Zero Init",
        legal_name: "Zero Init LLC",
        timezone: "America/New_York",
        country_code: "US"
      )
      approver = cash_distinct_approver(store: store, assigned_by: @actor)
      initialization = Cash::InitializeSafe.call(
        store: store,
        performed_by: @actor,
        approved_by: approver,
        count_cents: 0,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )

      assert_equal 0, initialization.counted_cents
      assert Cash::Locations.safe_for!(store).initialized?
      assert_equal 0, initialization.cash_operation.cash_entries.count
      assert_equal 0, Cash::Locations.safe_for!(store).expected_balance_cents
    end

    test "manager-assisted close keeps the cashier and records the closer" do
      cashier = pos_transacting_user(store: @store, assigned_by: @actor, username: "till_cashier")
      context = pos_open_context(store: @store, actor: cashier, opening_float_cents: 2000)
      manager = pos_store_manager(store: @store, assigned_by: @actor, username: "close_mgr")

      session = pos_close_session!(
        session: context[:session],
        actor: manager,
        closing_count_cents: 2000,
        close_reason_code: "cashier_left"
      )

      assert_equal cashier.id, session.cashier_user_id
      assert_equal manager.id, session.closed_by_user_id
      assert_equal "cashier_left", session.close_reason_code
    end
  end
end
