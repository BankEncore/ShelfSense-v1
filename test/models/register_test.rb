# frozen_string_literal: true

require "test_helper"

class RegisterTest < ActiveSupport::TestCase
  setup do
    @bootstrap = Installation::Bootstrap.call(
      organization_name: "Example Books",
      store_number: "1",
      store_code: "main",
      store_name: "Main Store",
      store_timezone: "America/New_York",
      store_country_code: "US",
      admin_username: "admin",
      admin_display_name: "Admin User",
      admin_password: "correct-horse-battery"
    )
    @store = @bootstrap[:store]
  end

  test "requires a unique register_number per store" do
    Register.create!(store: @store, register_number: "01", name: "Front")
    duplicate = Register.new(store: @store, register_number: "01", name: "Other")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:register_number], "has already been taken"
  end

  test "allows the same register_number in another store" do
    other = Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )
    Register.create!(store: @store, register_number: "01", name: "Front")
    copy = Register.new(store: other, register_number: "01", name: "Front")

    assert copy.valid?
  end

  test "register_number is immutable after a receipt has been issued" do
    register = Register.create!(store: @store, register_number: "01", name: "Front", receipt_sequence: 1)
    register.register_number = "02"

    assert_not register.valid?
    assert_includes register.errors[:register_number], "cannot change after a receipt has been issued"
  end

  test "register_number may change before any receipt is issued" do
    register = Register.create!(store: @store, register_number: "01", name: "Front")
    register.update!(register_number: "02")

    assert_equal "02", register.reload.register_number
  end
end
