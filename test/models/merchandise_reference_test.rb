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
      inventory_mode: "inventory",
      pricing_method: "fixed"
    )
    assert_not duplicate.valid?
    assert_equal "book", duplicate.code
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "merchandise condition code is unique" do
    merchandise_condition(code: "like_new")
    duplicate = MerchandiseCondition.new(
      code: "LIKE_NEW",
      name: "Like new",
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

  test "inventory_mode accepts inventory and non_inventory" do
    inventory = merchandise_class(code: "book", inventory_mode: "inventory", default_standard_department: @department)
    service = merchandise_class(code: "service", inventory_mode: "non_inventory", default_standard_department: @department)

    assert inventory.inventory?
    assert service.non_inventory?
    invalid = MerchandiseClass.new(
      code: "bad",
      name: "Bad",
      inventory_mode: "quantity",
      pricing_method: "fixed"
    )
    assert_not invalid.valid?
    assert_includes invalid.errors[:inventory_mode], "is not included in the list"
  end
end
