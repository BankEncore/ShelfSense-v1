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

  test "database rejects a second working transaction on the same session" do
    period = open_period
    session = PosSession.create!(
      store: @store,
      register: @register,
      reporting_period: period,
      cashier_user: @user,
      status: "open",
      opened_at: Time.current
    )
    PosTransaction.create!(
      store: @store,
      register: @register,
      pos_session: session,
      reporting_period: period,
      cashier_user: @user,
      status: "working",
      currency_code: "USD"
    )

    duplicate = PosTransaction.new(
      store: @store,
      register: @register,
      pos_session: session,
      reporting_period: period,
      cashier_user: @user,
      status: "working",
      currency_code: "USD"
    )
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save! }
  end

  test "completed and cancelled history does not block a new working transaction" do
    period = open_period
    session = PosSession.create!(
      store: @store,
      register: @register,
      reporting_period: period,
      cashier_user: @user,
      status: "open",
      opened_at: Time.current
    )
    PosTransaction.create!(
      store: @store,
      register: @register,
      pos_session: session,
      reporting_period: period,
      cashier_user: @user,
      status: "cancelled",
      cancelled_at: Time.current,
      currency_code: "USD"
    )
    working = PosTransaction.create!(
      store: @store,
      register: @register,
      pos_session: session,
      reporting_period: period,
      cashier_user: @user,
      status: "working",
      currency_code: "USD"
    )
    assert working.working?
  end

  test "different sessions may each have one working transaction" do
    other_register = Register.create!(store: @store, register_number: 2, name: "Back")
    first_period = open_period
    first_session = PosSession.create!(
      store: @store,
      register: @register,
      reporting_period: first_period,
      cashier_user: @user,
      status: "open",
      opened_at: Time.current
    )
    second_period = PosReportingPeriod.create!(
      store: @store,
      register: other_register,
      status: "open",
      opened_at: Time.current,
      business_date: Date.new(2026, 8, 16)
    )
    second_session = PosSession.create!(
      store: @store,
      register: other_register,
      reporting_period: second_period,
      cashier_user: @user,
      status: "open",
      opened_at: Time.current
    )

    first = PosTransaction.create!(
      store: @store,
      register: @register,
      pos_session: first_session,
      reporting_period: first_period,
      cashier_user: @user,
      status: "working",
      currency_code: "USD"
    )
    second = PosTransaction.create!(
      store: @store,
      register: other_register,
      pos_session: second_session,
      reporting_period: second_period,
      cashier_user: @user,
      status: "working",
      currency_code: "USD"
    )
    assert first.working?
    assert second.working?
  end

  test "pos.transact is seeded for associate and store manager" do
    assert Permission.exists?(key: "pos.transact")
    assert Role.find_by!(key: "associate").permissions.exists?(key: "pos.transact")
    assert Role.find_by!(key: "store_manager").permissions.exists?(key: "pos.transact")
  end

  test "controlled-action permissions are seeded by role" do
    associate = Role.find_by!(key: "associate")
    manager = Role.find_by!(key: "store_manager")
    %w[price_override line_discount tax_class_override].each do |action|
      assert Permission.exists?(key: "pos.#{action}.perform")
      assert Permission.exists?(key: "pos.#{action}.approve")
      assert associate.permissions.exists?(key: "pos.#{action}.perform")
      assert_not associate.permissions.exists?(key: "pos.#{action}.approve")
      assert manager.permissions.exists?(key: "pos.#{action}.perform")
      assert manager.permissions.exists?(key: "pos.#{action}.approve")
    end
    assert_not Permission.exists?(key: "pos.unlinked_return.perform")
    assert_not Permission.exists?(key: "pos.post_void.perform")
  end

  test "pos.manage_tender_types is seeded for system administrator only" do
    assert Permission.exists?(key: "pos.manage_tender_types")
    assert Role.find_by!(key: "system_administrator").permissions.exists?(key: "pos.manage_tender_types")
    assert_not Role.find_by!(key: "associate").permissions.exists?(key: "pos.manage_tender_types")
    assert_not Role.find_by!(key: "store_manager").permissions.exists?(key: "pos.manage_tender_types")
  end

  test "database rejects a second Cash payment on the same transaction" do
    period = open_period
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
    cash = TenderType.find_by!(code: "cash")
    attrs = {
      pos_transaction: transaction,
      configured_tender_type: cash,
      tender_type: "cash",
      tender_name: "Cash",
      behavioral_category: "cash",
      direction: "payment",
      amount_cents: 100,
      amount_presented_cents: 100,
      change_cents: 0
    }
    PosTender.create!(attrs.merge(tender_number: 1))
    duplicate = PosTender.new(attrs.merge(tender_number: 2))
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save! }
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

  test "pos_controlled_actions timestamps are timestamptz" do
    %w[created_at updated_at executed_at].each do |column|
      assert_equal "timestamp with time zone", postgres_type("pos_controlled_actions", column), column
    end
  end

  private

  def postgres_type(table, column)
    PosControlledAction.connection.select_value(
      "SELECT format_type(a.atttypid, a.atttypmod)
       FROM pg_attribute a
       JOIN pg_class c ON c.oid = a.attrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relname = #{PosControlledAction.connection.quote(table)}
         AND a.attname = #{PosControlledAction.connection.quote(column)}
         AND a.attnum > 0
         AND NOT a.attisdropped"
    )
  end

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
