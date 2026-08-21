# frozen_string_literal: true

require "test_helper"

class MerchandiseReferenceTest < ActiveSupport::TestCase
  setup do
    @tax = tax_class(code: "standard")
    @department = department(code: "books")
  end

  test "merchandise class code is unique" do
    merchandise_class(code: "book", department: @department)
    duplicate = MerchandiseClass.new(
      code: " Book ",
      name: "Other",
      department: @department,
      merchandise_class_number: "2",
      default_tax_class: @tax,
      default_inventory_mode: "inventory",
      default_pricing_method: "fixed"
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

  test "merchandise category path_label includes ancestors" do
    root = merchandise_category(name: "Books", code: "books_root")
    parent = merchandise_category(name: "Fiction", code: "fiction", parent: root)
    child = merchandise_category(name: "Mystery", code: "mystery", parent: parent)

    assert_equal "Books", root.path_label
    assert_equal "Books > Fiction", parent.path_label
    assert_equal "Books > Fiction > Mystery", child.path_label
  end

  test "admin labels and hierarchical category options" do
    dept = department(code: "trade", name: "General Trade Books", department_number: "110")
    assert_equal "110 - General Trade Books", dept.admin_label

    klass = merchandise_class(code: "book", name: "Physical book", department: @department, merchandise_class_number: "1")
    assert_equal "BOOKS / 1 - Physical book", klass.admin_label

    condition = merchandise_condition(code: "good", name: "Good")
    assert_equal "Good", condition.admin_label

    root = merchandise_category(name: "Books", code: "books_root", display_order: 1)
    parent = merchandise_category(name: "Fiction", code: "fiction", parent: root, display_order: 2)
    sibling = merchandise_category(name: "Anthologies", code: "anthologies", parent: root, display_order: 1)
    child = merchandise_category(name: "Mystery", code: "mystery", parent: parent, display_order: 0)

    options = MerchandiseCategory.options_for_select([ root, parent, sibling, child ])
    assert_equal [ root.id, sibling.id, parent.id, child.id ], options.map(&:last)
    assert_equal "Books", options[0].first
    assert_equal "Anthologies", options[1].first.delete("\u00A0")
    assert_equal "Fiction", options[2].first.delete("\u00A0")
    assert_equal "Mystery", options[3].first.delete("\u00A0")
    assert_operator options[1].first.count("\u00A0"), :>, 0
    assert_operator options[3].first.count("\u00A0"), :>, options[1].first.count("\u00A0")
  end

  test "default_inventory_mode accepts inventory and non_inventory" do
    inventory = merchandise_class(code: "book", inventory_mode: "inventory", department: @department)
    service = merchandise_class(code: "service", inventory_mode: "non_inventory", department: @department)

    assert inventory.inventory?
    assert service.non_inventory?
    invalid = MerchandiseClass.new(
      code: "bad",
      name: "Bad",
      department: @department,
      merchandise_class_number: "9",
      default_tax_class: @tax,
      default_inventory_mode: "quantity",
      default_pricing_method: "fixed"
    )
    assert_not invalid.valid?
    assert_includes invalid.errors[:default_inventory_mode], "is not included in the list"
  end

  test "buyback requires used merchandise and inventory mode" do
    klass = merchandise_class(code: "gift_card", inventory_mode: "non_inventory", department: @department)
    klass.buyback_allowed = true
    assert_not klass.valid?
    assert_includes klass.errors[:buyback_allowed], "requires used merchandise allowed and inventory mode"
  end

  test "default_supplier_returnable is the returnability column" do
    klass = merchandise_class(code: "book", department: @department)
    assert klass.respond_to?(:default_supplier_returnable)
    assert_not klass.respond_to?(:default_returnable)
  end

  test "codes are immutable after create" do
    klass = merchandise_class(code: "immutable", department: @department)
    klass.code = "changed"
    assert_not klass.valid?
    assert_includes klass.errors[:code], "cannot be changed after creation"
  end

  test "blank code generates from name" do
    klass = MerchandiseClass.create!(
      name: "Used Books & Media",
      department: @department,
      merchandise_class_number: "3",
      default_tax_class: @tax,
      default_inventory_mode: "inventory",
      default_pricing_method: "fixed"
    )
    assert_equal "used_books_media", klass.code
  end
end
