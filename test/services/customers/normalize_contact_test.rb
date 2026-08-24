# frozen_string_literal: true

require "test_helper"

module Customers
  class NormalizeContactTest < ActiveSupport::TestCase
    test "email strips and downcases" do
      assert_equal "a@b.com", Customers::NormalizeContact.email("  A@B.COM ")
      assert_nil Customers::NormalizeContact.email("   ")
    end

    test "phone normalizes US ten digit to E.164" do
      assert_equal "+15550101234", Customers::NormalizeContact.phone("(555) 010-1234")
      assert_equal "+15550101234", Customers::NormalizeContact.phone("1-555-010-1234")
      assert_equal "+442071838750", Customers::NormalizeContact.phone("+44 20 7183 8750")
    end

    test "unparseable phone returns nil" do
      assert_nil Customers::NormalizeContact.phone("call me")
      assert_nil Customers::NormalizeContact.phone("123")
    end
  end
end
