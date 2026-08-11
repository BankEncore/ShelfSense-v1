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

  test "code cannot change after create" do
    record = tax_class(code: "books")
    record.code = "other"
    assert_not record.valid?
    assert_includes record.errors[:code], "cannot be changed after creation"
  end

  test "reactivate succeeds when inactive" do
    actor = actor_user
    record = tax_class(code: "inactive_tax", active: false)
    Configuration::Reactivate.call(
      record: record,
      actor: actor,
      audit_action: "tax_classes.reactivate"
    )
    assert record.reload.active?
  end
end
