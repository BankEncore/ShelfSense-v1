# frozen_string_literal: true

require "test_helper"

class PosCashAccountabilityTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 10, unit_cost_cents: 100)
  end

  test "opens a session with an explicit opening float including zero" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)
    session = Pos::OpenSession.call(
      store: @store,
      register: register,
      actor: @actor,
      reporting_period: period,
      opening_float_cents: 0
    )

    assert session.open?
    assert_equal 0, session.opening_float_cents
    assert_nil session.closing_count_cents
    event = AuditEvent.where(action: "pos.session.opened").order(:created_at).last
    assert_equal "succeeded", event.outcome
    assert_equal 0, event.after_values["opening_float_cents"]
  end

  test "rejects a negative opening float" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)

    error = assert_raises(Pos::Error) do
      Pos::OpenSession.call(
        store: @store,
        register: register,
        actor: @actor,
        reporting_period: period,
        opening_float_cents: -1
      )
    end
    assert_match(/opening float/, error.message)
    assert_equal 0, PosSession.count
  end

  test "close persists expected cash and variance from completed cash tenders" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    complete_cash_sale(session: context[:session], amount_presented_cents: 2500)

    session = Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 12_100
    )

    assert session.closed?
    assert_equal 10_000, session.opening_float_cents
    assert_equal 12_099, session.closing_expected_cash_cents
    assert_equal 12_100, session.closing_count_cents
    assert_equal 1, session.closing_variance_cents
    event = AuditEvent.where(action: "pos.session.closed").order(:created_at).last
    assert_equal 12_100, event.after_values["closing_count_cents"]
    assert_equal 12_099, event.after_values["closing_expected_cash_cents"]
    assert_equal 1, event.after_values["closing_variance_cents"]
  end

  test "close records a negative variance when counted is below expected" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    complete_cash_sale(session: context[:session], amount_presented_cents: 2500)

    session = Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].reload.lock_version,
      closing_count_cents: 12_000
    )

    assert_equal 12_099, session.closing_expected_cash_cents
    assert_equal(-99, session.closing_variance_cents)
  end

  test "cancelled transactions do not change expected cash" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 5_000)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    Pos::CancelTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )

    session = Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].reload.lock_version,
      closing_count_cents: 5_000
    )

    assert_equal 5_000, session.closing_expected_cash_cents
    assert_equal 0, session.closing_variance_cents
  end

  test "close rejects a stale lock_version" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)

    assert_raises(Pos::StaleObject) do
      Pos::CloseSession.call(
        session: context[:session],
        actor: @actor,
        expected_lock_version: context[:session].lock_version - 1,
        closing_count_cents: 0
      )
    end
    assert context[:session].reload.open?
  end

  test "second cashier cannot close another cashier's session" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_cash")

    assert_raises(Pos::Denied) do
      Pos::CloseSession.call(
        session: context[:session],
        actor: other,
        expected_lock_version: context[:session].lock_version,
        closing_count_cents: 0
      )
    end
    assert context[:session].reload.open?
  end

  test "finalize is blocked while a session is open" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)

    error = assert_raises(Pos::Error) do
      Pos::FinalizeReportingPeriod.call(
        period: context[:period],
        actor: @actor,
        expected_lock_version: context[:period].lock_version
      )
    end
    assert_match(/open session/, error.message)
    assert context[:period].reload.open?
  end

  test "finalize after close persists immutable Z snapshots from completed facts" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    complete_cash_sale(session: context[:session], amount_presented_cents: 2500)
    Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 12_000
    )

    period = Pos::FinalizeReportingPeriod.call(
      period: context[:period],
      actor: @actor,
      expected_lock_version: context[:period].lock_version
    )

    assert period.finalized?
    assert_equal @actor.id, period.finalized_by_user_id
    assert_equal 1, period.finalized_transaction_count
    assert_equal 1999, period.finalized_subtotal_cents
    assert_equal 0, period.finalized_discount_cents
    assert_equal 100, period.finalized_tax_cents
    assert_equal 2099, period.finalized_total_cents
    assert_equal 2099, period.finalized_cash_payment_cents
    assert_equal 0, period.finalized_card_payment_cents
    assert_equal 0, period.finalized_check_payment_cents
    assert_equal 0, period.finalized_other_payment_cents
    assert_equal 1, period.finalized_session_count
    assert_equal 10_000, period.finalized_opening_float_cents_sum
    assert_equal 12_099, period.finalized_closing_expected_cash_cents_sum
    assert_equal 12_000, period.finalized_closing_count_cents_sum
    assert_equal(-99, period.finalized_closing_variance_cents_sum)
    event = AuditEvent.where(action: "pos.reporting_period.finalized").order(:created_at).last
    assert_equal 1, event.after_values["finalized_transaction_count"]
    assert_equal 2099, event.after_values["finalized_cash_payment_cents"]
    assert_equal @actor.id, event.after_values["finalized_by_user_id"]
  end

  test "another store cashier may finalize a period they did not cashier" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 0
    )
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "z_closer")

    period = Pos::FinalizeReportingPeriod.call(
      period: context[:period],
      actor: other,
      expected_lock_version: context[:period].lock_version
    )

    assert period.finalized?
    assert_equal other.id, period.finalized_by_user_id
  end

  test "finalize of an unused period stores an all-zero Z" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)

    period = Pos::FinalizeReportingPeriod.call(
      period: period,
      actor: @actor,
      expected_lock_version: period.lock_version
    )

    assert period.finalized?
    assert_equal @actor.id, period.finalized_by_user_id
    assert_equal 0, period.finalized_transaction_count
    assert_equal 0, period.finalized_subtotal_cents
    assert_equal 0, period.finalized_discount_cents
    assert_equal 0, period.finalized_tax_cents
    assert_equal 0, period.finalized_total_cents
    assert_equal 0, period.finalized_cash_payment_cents
    assert_equal 0, period.finalized_card_payment_cents
    assert_equal 0, period.finalized_check_payment_cents
    assert_equal 0, period.finalized_other_payment_cents
    assert_equal 0, period.finalized_session_count
    assert_equal 0, period.finalized_opening_float_cents_sum
    assert_equal 0, period.finalized_closing_expected_cash_cents_sum
    assert_equal 0, period.finalized_closing_count_cents_sum
    assert_equal 0, period.finalized_closing_variance_cents_sum
  end

  test "finalize rejects a stale lock_version" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)

    assert_raises(Pos::StaleObject) do
      Pos::FinalizeReportingPeriod.call(
        period: period,
        actor: @actor,
        expected_lock_version: period.lock_version - 1
      )
    end
    assert period.reload.open?
  end

  test "closed session and finalized period are immutable" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    session = Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 0
    )
    period = Pos::FinalizeReportingPeriod.call(
      period: context[:period],
      actor: @actor,
      expected_lock_version: context[:period].lock_version
    )

    assert_raises(ActiveRecord::ReadOnlyRecord) { session.update!(opening_float_cents: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { period.update!(business_date: Date.new(2020, 1, 1)) }
  end

  test "close session rejects client-supplied expected or variance" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)

    assert_raises(ArgumentError) do
      Pos::CloseSession.call(
        session: context[:session],
        actor: @actor,
        expected_lock_version: context[:session].lock_version,
        closing_count_cents: 0,
        closing_expected_cash_cents: 0
      )
    end
    assert_raises(ArgumentError) do
      Pos::CloseSession.call(
        session: context[:session],
        actor: @actor,
        expected_lock_version: context[:session].lock_version,
        closing_count_cents: 0,
        closing_variance_cents: 0
      )
    end
    assert context[:session].reload.open?
  end

  test "closed session totals return persisted close snapshots" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    complete_cash_sale(session: context[:session], amount_presented_cents: 2500)
    session = Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 12_000
    )

    totals = Pos::SessionTotals.for(session)
    assert_equal session.closing_expected_cash_cents, totals.expected_cash_cents
    assert_equal session.closing_count_cents, totals.closing_count_cents
    assert_equal session.closing_variance_cents, totals.closing_variance_cents
    assert_equal(-99, totals.closing_variance_cents)
    assert_equal session.pos_transactions.completed.sum(:total_cents), totals.total_cents
  end

  test "finalized period totals return persisted Z snapshots" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    complete_cash_sale(session: context[:session], amount_presented_cents: 2500)
    Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 12_000
    )
    period = Pos::FinalizeReportingPeriod.call(
      period: context[:period],
      actor: @actor,
      expected_lock_version: context[:period].lock_version
    )

    totals = Pos::PeriodTotals.for(period)
    assert_equal period.finalized_transaction_count, totals.transaction_count
    assert_equal period.finalized_cash_payment_cents, totals.cash_payment_cents
    assert_equal period.finalized_closing_variance_cents_sum, totals.closing_variance_cents_sum
    assert_equal(-99, totals.closing_variance_cents_sum)
  end

  test "finalize is blocked by a working transaction even if the session row is closed" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    Pos::StartTransaction.call(session: context[:session], actor: @actor)
    context[:session].update_columns(
      status: "closed",
      closed_at: Time.current,
      closing_expected_cash_cents: 0,
      closing_count_cents: 0,
      closing_variance_cents: 0
    )

    error = assert_raises(Pos::Error) do
      Pos::FinalizeReportingPeriod.call(
        period: context[:period],
        actor: @actor,
        expected_lock_version: context[:period].lock_version
      )
    end
    assert_match(/working transaction/, error.message)
    assert context[:period].reload.open?
  end

  test "open reporting period rejects a business date that is not the store calendar date" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")

    error = assert_raises(Pos::Error) do
      Pos::OpenReportingPeriod.call(
        store: @store,
        register: register,
        actor: @actor,
        business_date: Date.new(2020, 1, 1)
      )
    end
    assert_match(/business date/, error.message)
    assert_equal 0, PosReportingPeriod.count
  end

  test "open reporting period accepts the calculated store business date" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")

    travel_to 1.minute.from_now do
      calculated = BusinessDate.for_store(@store)
      period = Pos::OpenReportingPeriod.call(
        store: @store,
        register: register,
        actor: @actor,
        business_date: calculated
      )

      assert_equal calculated, period.business_date
      assert_equal Time.current, period.opened_at
    end
  end

  test "open and close commands reject caller-supplied lifecycle timestamps" do
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    supplied = 3.days.ago

    assert_raises(ArgumentError) do
      Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor, opened_at: supplied)
    end
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)
    assert_raises(ArgumentError) do
      Pos::OpenSession.call(
        store: @store,
        register: register,
        actor: @actor,
        reporting_period: period,
        opening_float_cents: 0,
        opened_at: supplied
      )
    end
    session = Pos::OpenSession.call(
      store: @store,
      register: register,
      actor: @actor,
      reporting_period: period,
      opening_float_cents: 0
    )
    assert_raises(ArgumentError) do
      Pos::CloseSession.call(
        session: session,
        actor: @actor,
        expected_lock_version: session.lock_version,
        closing_count_cents: 0,
        closed_at: supplied
      )
    end
    Pos::CloseSession.call(
      session: session,
      actor: @actor,
      expected_lock_version: session.lock_version,
      closing_count_cents: 0
    )
    assert_raises(ArgumentError) do
      Pos::FinalizeReportingPeriod.call(
        period: period,
        actor: @actor,
        expected_lock_version: period.lock_version,
        closed_at: supplied
      )
    end
  end

  test "unauthorized actor cannot finalize a reporting period" do
    clerk = User.create!(
      username: "no_pos_finalize",
      display_name: "No POS",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)

    assert_raises(Pos::Denied) do
      Pos::FinalizeReportingPeriod.call(
        period: period,
        actor: clerk,
        expected_lock_version: period.lock_version
      )
    end

    period.reload
    assert period.open?
    assert_nil period.finalized_by_user_id
    assert_nil period.finalized_transaction_count
    assert_nil period.closed_at
    assert_equal 0, AuditEvent.where(action: "pos.reporting_period.finalized", outcome: "succeeded").count
  end

  test "multi-session Z sums independent session snapshots without a drawer chain" do
    context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    complete_cash_sale(session: context[:session], amount_presented_cents: 2500)
    first = Pos::CloseSession.call(
      session: context[:session],
      actor: @actor,
      expected_lock_version: context[:session].lock_version,
      closing_count_cents: 12_000
    )
    second_session = Pos::OpenSession.call(
      store: @store,
      register: context[:register],
      actor: @actor,
      reporting_period: context[:period],
      opening_float_cents: 5_000
    )
    second = Pos::CloseSession.call(
      session: second_session,
      actor: @actor,
      expected_lock_version: second_session.lock_version,
      closing_count_cents: 5_000
    )

    period = Pos::FinalizeReportingPeriod.call(
      period: context[:period],
      actor: @actor,
      expected_lock_version: context[:period].lock_version
    )

    assert_equal 1, period.finalized_transaction_count
    assert_equal 1999, period.finalized_subtotal_cents
    assert_equal 2099, period.finalized_cash_payment_cents
    assert_equal 2, period.finalized_session_count
    assert_equal 15_000, period.finalized_opening_float_cents_sum
    assert_equal first.closing_expected_cash_cents + second.closing_expected_cash_cents,
                 period.finalized_closing_expected_cash_cents_sum
    assert_equal first.closing_count_cents + second.closing_count_cents,
                 period.finalized_closing_count_cents_sum
    assert_equal first.closing_variance_cents + second.closing_variance_cents,
                 period.finalized_closing_variance_cents_sum
    assert_equal(-99, period.finalized_closing_variance_cents_sum)
  end

  test "unauthorized actor cannot open a session" do
    clerk = User.create!(
      username: "no_pos_cash",
      display_name: "No POS",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    period = Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor)

    assert_raises(Pos::Denied) do
      Pos::OpenSession.call(
        store: @store,
        register: register,
        actor: clerk,
        reporting_period: period,
        opening_float_cents: 0
      )
    end
  end

  private

  def complete_cash_sale(session:, amount_presented_cents:)
    transaction = Pos::StartTransaction.call(session: session, actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: amount_presented_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
  end
end
