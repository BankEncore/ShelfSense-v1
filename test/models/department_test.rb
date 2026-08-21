# frozen_string_literal: true

require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  setup do
    @inventory = inventory_gl
    @cogs = cogs_gl
    @sales = sales_gl
  end

  test "rejects GL mapping with incompatible type or category" do
    record = Department.new(
      code: "new_books",
      name: "New Books",
      department_number: "NEW_BOOKS",
      inventory_asset_gl_account: @sales
    )
    assert_not record.valid?
    assert_includes record.errors[:inventory_asset_gl_account_id], "must be asset/inventory"
  end

  test "rejects inactive GL on new mapping" do
    inactive = inventory_gl(account_number: "1299")
    inactive.update!(active: false)

    record = Department.new(
      code: "cafe",
      name: "Café",
      department_number: "CAFE",
      inventory_asset_gl_account: inactive
    )
    assert_not record.valid?
    assert_includes record.errors[:inventory_asset_gl_account_id], "must be an active posting account"
  end

  test "historical inactive GL mapping is retained when editing unrelated fields" do
    record = department(
      code: "media",
      inventory_asset_gl_account: @inventory,
      cost_of_goods_sold_gl_account: @cogs,
      sales_revenue_gl_account: @sales
    )
    @inventory.update!(active: false)

    record.name = "Media Updated"
    assert record.valid?
    assert record.save
    assert_equal @inventory.id, record.reload.inventory_asset_gl_account_id
  end

  test "changing a mapping revalidates assignability" do
    record = department(
      code: "gifts",
      inventory_asset_gl_account: @inventory
    )
    inactive = inventory_gl(account_number: "1210")
    inactive.update!(active: false)

    record.inventory_asset_gl_account = inactive
    assert_not record.valid?
    assert_includes record.errors[:inventory_asset_gl_account_id], "must be an active posting account"
  end
end
