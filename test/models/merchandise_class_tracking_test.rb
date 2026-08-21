# frozen_string_literal: true

require "test_helper"

class MerchandiseClassTrackingTest < ActiveSupport::TestCase
  include Phase2Fixtures

  setup do
    @actor = actor_user
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)

    @tax = tax_class(code: "cls_track_tax")
    @department = department(code: "cls_track_dept")
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
  end

  test "inventory to non_inventory is rejected on variant after history" do
    klass = merchandise_class(
      code: "cls_hist_inv",
      department: @department,
      pricing_method: "fixed"
    )
    variant = create_standard_variant(klass)
    post_opening(variant)

    variant.inventory_mode = "non_inventory"
    assert_not variant.valid?
    assert_includes variant.errors[:base],
                    "cannot change inventory tracking method after inventory history exists"
  end

  test "non_inventory to inventory is rejected on variant after history" do
    klass = merchandise_class(
      code: "cls_hist_non",
      inventory_mode: "non_inventory",
      department: @department,
      pricing_method: "fixed"
    )
    variant = create_standard_variant(klass)
    InventoryBalance.create!(
      store: @store,
      product_variant: variant,
      on_hand_quantity: 0,
      inventory_value_cents: 0
    )

    variant.inventory_mode = "inventory"
    assert_not variant.valid?
    assert_includes variant.errors[:base],
                    "cannot change inventory tracking method after inventory history exists"
  end

  test "inventory_mode may change on variant when no history exists" do
    klass = merchandise_class(
      code: "cls_no_hist",
      department: @department,
      pricing_method: "fixed"
    )
    variant = create_standard_variant(klass)

    variant.update!(inventory_mode: "non_inventory")
    assert_equal "non_inventory", variant.reload.inventory_mode

    variant.update!(inventory_mode: "inventory")
    assert_equal "inventory", variant.reload.inventory_mode
  end

  test "merchandise class change is blocked after inventory history" do
    other = merchandise_class(
      code: "cls_other_dept",
      department: department(code: "cls_other_dept_parent"),
      pricing_method: "fixed",
      default_tax_class: @tax
    )
    klass = merchandise_class(
      code: "cls_hist_class",
      department: @department,
      pricing_method: "fixed"
    )
    variant = create_standard_variant(klass)
    post_opening(variant)

    variant.merchandise_class = other
    assert_not variant.valid?
    assert_includes variant.errors[:merchandise_class_id],
                    "cannot be changed after inventory or POS history exists; a controlled reclassification is required"
  end

  private

  def create_standard_variant(klass)
    product = Products::Create.call(
      attributes: { name: "Class tracking #{klass.code}", status: "active" },
      actor: @actor
    )
    ProductVariants::Create.call(
      product: product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: klass.id,
        regular_price_cents: 1999
      },
      actor: @actor
    )
  end

  def post_opening(variant)
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: variant,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100
    )
  end
end
