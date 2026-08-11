# frozen_string_literal: true

require "test_helper"

class TaxClassTest < ActiveSupport::TestCase
  test "code is unique after normalization" do
    tax_class(code: "taxable")
    duplicate = TaxClass.new(code: " Taxable ", name: "Other")
    assert_not duplicate.valid?
    assert_equal "taxable", duplicate.code
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "normalize_code downcases and replaces spaces" do
    record = TaxClass.create!(code: " Physical Book ", name: "Physical book")
    assert_equal "physical_book", record.code
  end
end
