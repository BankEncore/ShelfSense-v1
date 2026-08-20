# frozen_string_literal: true

require "test_helper"

class StoreTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
  end

  test "store_number coerces leading zeroes to the same integer" do
    other = Store.new(
      store_number: "01",
      code: "east",
      name: "East Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )

    assert_not other.valid?
    assert_includes other.errors[:store_number], "has already been taken"
    other.store_number = 2
    assert other.valid?
    other.save!
    assert_equal 2, other.reload.store_number
  end

  test "store_number is immutable after a register has issued a receipt" do
    Register.create!(store: @store, register_number: 1, name: "Front", receipt_sequence: 1)
    @store.reload
    @store.store_number = 9

    assert_not @store.valid?
    assert_includes @store.errors[:store_number], "cannot change after a receipt has been issued"
  end

  test "store_number may change before any receipt history exists" do
    @store.update!(store_number: 8)

    assert_equal 8, @store.reload.store_number
  end

  test "cannot deactivate while an open reporting period exists" do
    Store.create!(
      store_number: 2,
      code: "east",
      name: "East Store", legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    register = Register.create!(store: @store, register_number: 1, name: "Front")
    PosReportingPeriod.create!(
      store: @store,
      register: register,
      status: "open",
      opened_at: Time.current,
      business_date: Date.new(2026, 8, 16)
    )

    @store.active = false
    assert_not @store.valid?
    assert_includes @store.errors[:base], "cannot deactivate while an open reporting period exists"
  end
end
