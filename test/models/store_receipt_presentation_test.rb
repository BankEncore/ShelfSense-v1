# frozen_string_literal: true

require "test_helper"

class StoreReceiptPresentationTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @settings = @bootstrap[:settings]
  end

  test "active stores require a legal name and never copy the operational name" do
    store = Store.new(
      store_number: 2,
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )

    assert_not store.valid?
    assert_includes store.errors[:legal_name], "can't be blank"
    refute_equal store.name, store.legal_name
  end

  test "legacy blank legal name may be deactivated" do
    store = Store.create!(
      store_number: 2,
      code: "east",
      name: "East Store",
      legal_name: "East Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    store.update_columns(legal_name: nil)

    assert store.update(active: false, deactivated_at: Time.current, deactivated_by: @bootstrap[:administrator])
    assert_nil store.reload.legal_name
  end

  test "activation requires legal name" do
    store = Store.create!(
      store_number: 2,
      code: "east",
      name: "East Store",
      legal_name: "East Books LLC",
      timezone: "America/New_York",
      country_code: "US",
      active: false
    )
    store.update_columns(legal_name: nil)
    store.active = true

    assert_not store.valid?
    assert_includes store.errors[:legal_name], "can't be blank"
  end

  test "custom header mode requires nonblank text and inherit uses the system default" do
    @settings.update!(default_receipt_header: "Proud Member of the ABA")
    @store.update!(receipt_header_mode: "inherit", receipt_header: "")
    assert_equal "Proud Member of the ABA", @store.effective_receipt_header

    @store.receipt_header_mode = "custom"
    @store.receipt_header = ""
    assert_not @store.valid?

    @store.update!(receipt_header_mode: "custom", receipt_header: "Thank you for shopping local")
    assert_equal "Thank you for shopping local", @store.effective_receipt_header

    @store.update!(receipt_header_mode: "none")
    assert_nil @store.effective_receipt_header
    assert_equal "Thank you for shopping local", @store.reload.receipt_header
  end
end
