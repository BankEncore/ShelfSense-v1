# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "format_money_cents formats signed minor units" do
    assert_equal "$12.50", format_money_cents(1250)
    assert_equal "-$0.99", format_money_cents(-99)
    assert_includes format_money_cents(nil), "Not provided"
  end

  test "format_signed_money_cents prefixes a plus for positive amounts" do
    assert_equal "+$25.00", format_signed_money_cents(2500)
    assert_equal "-$20.00", format_signed_money_cents(-2000)
    assert_equal "$0.00", format_signed_money_cents(0)
  end

  test "money_field_value uses integer cents without floats" do
    assert_equal "12.50", money_field_value(1250)
    assert_equal "-0.99", money_field_value(-99)
    assert_nil money_field_value(nil)
  end

  test "status_badge maps product_variant scheme only" do
    html = status_badge("draft", scheme: :product_variant)
    assert_includes html, "Draft"
    assert_includes html, "status-badge--draft"

    assert_raises(ArgumentError) { status_badge("inactive", scheme: :product_variant) }
  end

  test "status_badge maps configuration scheme only" do
    html = status_badge("inactive", scheme: :configuration)
    assert_includes html, "Inactive"
    assert_includes html, "status-badge--inactive"

    assert_raises(ArgumentError) { status_badge("draft", scheme: :configuration) }
  end

  test "configuration_status_badge wraps boolean active flag" do
    assert_includes configuration_status_badge(true), "Active"
    assert_includes configuration_status_badge(false), "Inactive"
  end
end
