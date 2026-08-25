# frozen_string_literal: true

require "test_helper"

class Bibliographic::MsrpTest < ActiveSupport::TestCase
  test "converts dollar strings to integer cents" do
    assert_equal 1699, Bibliographic::Msrp.to_cents("16.99")
    assert_equal 1700, Bibliographic::Msrp.to_cents("$17")
    assert_equal 1_099_900, Bibliographic::Msrp.to_cents("10,999.00")
  end

  test "omits blank, negative, and unparseable MSRP" do
    assert_nil Bibliographic::Msrp.to_cents(nil)
    assert_nil Bibliographic::Msrp.to_cents("")
    assert_nil Bibliographic::Msrp.to_cents("  ")
    assert_nil Bibliographic::Msrp.to_cents("-1.00")
    assert_nil Bibliographic::Msrp.to_cents("0")
    assert_nil Bibliographic::Msrp.to_cents("free")
    assert_nil Bibliographic::Msrp.to_cents("16.9.9")
  end
end
