# frozen_string_literal: true

require "test_helper"

class PosSchemaTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @user = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
  end

  test "one open reporting period and session per register" do
    period = PosReportingPeriod.create!(
      store: @store,
      register: @register,
      status: "open",
      opened_at: Time.current,
      business_date: Date.new(2026, 8, 16)
    )
    session = PosSession.create!(
      store: @store,
      register: @register,
      reporting_period: period,
      cashier_user: @user,
      status: "open",
      opened_at: Time.current
    )
    transaction = PosTransaction.create!(
      store: @store,
      register: @register,
      pos_session: session,
      reporting_period: period,
      cashier_user: @user,
      status: "working",
      currency_code: "USD"
    )

    assert period.open?
    assert session.open?
    assert transaction.working?

    duplicate_period = PosReportingPeriod.new(
      store: @store,
      register: @register,
      status: "open",
      opened_at: Time.current,
      business_date: Date.new(2026, 8, 16)
    )
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate_period.save! }
  end

  test "pos.transact is seeded for associate and store manager" do
    assert Permission.exists?(key: "pos.transact")
    assert Role.find_by!(key: "associate").permissions.exists?(key: "pos.transact")
    assert Role.find_by!(key: "store_manager").permissions.exists?(key: "pos.transact")
  end

  test "closed session variance must equal count minus expected" do
    period = open_period
    session = PosSession.new(closed_session_attributes(period, expected: 100, count: 90, variance: 0))

    assert_not session.valid?
    assert_includes session.errors[:closing_variance_cents], "must equal closing count minus expected cash"

    session.closing_variance_cents = -10
    assert session.valid?
  end

  test "database rejects a closed session whose variance does not match count minus expected" do
    period = open_period
    session = PosSession.create!(closed_session_attributes(period, expected: 100, count: 90, variance: -10))

    assert_raises(ActiveRecord::StatementInvalid) do
      PosSession.transaction(requires_new: true) do
        PosSession.where(id: session.id).update_all(closing_variance_cents: 0)
      end
    end
  end

  test "finalized period variance sum must equal count sum minus expected sum" do
    period = PosReportingPeriod.new(finalized_period_attributes(expected_sum: 100, count_sum: 90, variance_sum: 0))

    assert_not period.valid?
    assert_includes period.errors[:finalized_closing_variance_cents_sum],
                    "must equal closing count sum minus expected cash sum"

    period.finalized_closing_variance_cents_sum = -10
    assert period.valid?
  end

  test "database rejects a finalized period whose variance sum does not match count minus expected" do
    period = PosReportingPeriod.create!(finalized_period_attributes(expected_sum: 100, count_sum: 90, variance_sum: -10))

    assert_raises(ActiveRecord::StatementInvalid) do
      PosReportingPeriod.transaction(requires_new: true) do
        PosReportingPeriod.where(id: period.id).update_all(finalized_closing_variance_cents_sum: 0)
      end
    end
  end

  private

  def open_period
    PosReportingPeriod.create!(
      store: @store,
      register: @register,
      status: "open",
      opened_at: Time.current,
      business_date: Date.new(2026, 8, 16)
    )
  end

  def closed_session_attributes(period, expected:, count:, variance:)
    {
      store: @store,
      register: @register,
      reporting_period: period,
      cashier_user: @user,
      status: "closed",
      opened_at: Time.current,
      closed_at: Time.current,
      opening_float_cents: 0,
      closing_expected_cash_cents: expected,
      closing_count_cents: count,
      closing_variance_cents: variance
    }
  end

  def finalized_period_attributes(expected_sum:, count_sum:, variance_sum:)
    {
      store: @store,
      register: @register,
      status: "finalized",
      opened_at: Time.current,
      closed_at: Time.current,
      business_date: Date.new(2026, 8, 16),
      finalized_by_user_id: @user.id,
      finalized_transaction_count: 0,
      finalized_subtotal_cents: 0,
      finalized_tax_cents: 0,
      finalized_total_cents: 0,
      finalized_cash_payment_cents: 0,
      finalized_session_count: 0,
      finalized_opening_float_cents_sum: 0,
      finalized_closing_expected_cash_cents_sum: expected_sum,
      finalized_closing_count_cents_sum: count_sum,
      finalized_closing_variance_cents_sum: variance_sum
    }
  end
end
