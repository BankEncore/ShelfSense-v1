# frozen_string_literal: true

require "test_helper"

class MerchandiseReferenceTest < ActiveSupport::TestCase
  setup do
    @tax = tax_class(code: "standard")
    @department = department(code: "books", default_tax_class: @tax)
  end

  test "merchandise class code is unique" do
    merchandise_class(code: "book", default_standard_department: @department)
    duplicate = MerchandiseClass.new(
      code: " Book ",
      name: "Other",
      inventory_tracking_mode: "quantity",
      pricing_method: "fixed"
    )
    assert_not duplicate.valid?
    assert_equal "book", duplicate.code
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "merchandise condition code is unique" do
    merchandise_condition(code: "new")
    duplicate = MerchandiseCondition.new(
      code: "NEW",
      name: "Brand new",
      department_basis: "standard",
      price_adjustment_bps: 10_000
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "merchandise category root name uniqueness is enforced" do
    merchandise_category(name: "Fiction")
    assert_raises(ActiveRecord::RecordNotUnique) do
      MerchandiseCategory.create!(name: "fiction", display_order: 0)
    end
  end

  test "merchandise category parent hierarchy cannot cycle" do
    parent = merchandise_category(name: "Parent")
    child = merchandise_category(name: "Child", parent: parent)

    parent.parent = child
    assert_not parent.valid?
    assert_includes parent.errors[:parent_id], "would create a hierarchy cycle"
  end

  test "used_basis? reflects department_basis" do
    standard = merchandise_condition(code: "new", department_basis: "standard")
    used = merchandise_condition(code: "used", department_basis: "used", price_adjustment_bps: 6_000)

    assert_not standard.used_basis?
    assert used.used_basis?
  end
end
