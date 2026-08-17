# frozen_string_literal: true

require "test_helper"

class PosSchemaTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @user = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: "01", name: "Front")
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
end
