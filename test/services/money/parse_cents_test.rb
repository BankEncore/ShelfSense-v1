# frozen_string_literal: true

require "test_helper"

class Money::ParseCentsTest < ActiveSupport::TestCase
  test "parses plain and currency formatted amounts" do
    assert_equal 1250, Money::ParseCents.call("12.50")
    assert_equal 1250, Money::ParseCents.call("$12.50")
    assert_equal 120_000, Money::ParseCents.call("1,200.00")
    assert_nil Money::ParseCents.call("")
    assert_nil Money::ParseCents.call(nil)
  end

  test "rejects invalid amounts" do
    assert_raises(Money::ParseCents::Error) { Money::ParseCents.call("abc") }
    assert_raises(Money::ParseCents::Error) { Money::ParseCents.call("12.345") }
  end
end
