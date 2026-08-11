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
    merchandise_category(name: "Fiction", code: "fiction_root")
    assert_raises(ActiveRecord::RecordNotUnique) do
      MerchandiseCategory.insert!({
        id: SecureRandom.uuid_v7,
        name: "fiction",
        code: "fiction_other",
        active: true,
        display_order: 0,
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
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

  test "buyback requires used merchandise and inventory mode" do
    klass = merchandise_class(code: "gift_card", inventory_mode: "non_inventory", default_standard_department: @department)
    klass.buyback_allowed = true
    assert_not klass.valid?
    assert_includes klass.errors[:buyback_allowed], "requires used merchandise allowed and inventory mode"
  end

  test "default_supplier_returnable is the returnability column" do
    klass = merchandise_class(code: "book", default_standard_department: @department)
    assert klass.respond_to?(:default_supplier_returnable)
    assert_not klass.respond_to?(:default_returnable)
  end

  test "codes are immutable after create" do
    klass = merchandise_class(code: "immutable", default_standard_department: @department)
    klass.code = "changed"
    assert_not klass.valid?
    assert_includes klass.errors[:code], "cannot be changed after creation"
  end

  test "blank code generates from name" do
    klass = MerchandiseClass.create!(
      name: "Used Books & Media",
      inventory_mode: "inventory",
      pricing_method: "fixed",
      default_standard_department: @department
    )
    assert_equal "used_books_media", klass.code
  end
end
