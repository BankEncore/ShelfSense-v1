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
    @department = department(code: "cls_track_dept", default_tax_class: @tax)
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
  end

  test "inventory to non_inventory is rejected after history" do
    klass = merchandise_class(
      code: "cls_hist_inv",
      default_standard_department: @department,
      pricing_method: "fixed"
    )
    variant = create_standard_variant(klass)
    post_opening(variant)

    klass.inventory_mode = "non_inventory"
    assert_not klass.valid?
    assert_includes klass.errors[:inventory_mode],
                    "cannot change inventory tracking method after inventory history exists"
  end

  test "non_inventory to inventory is rejected after history" do
    klass = merchandise_class(
      code: "cls_hist_non",
      inventory_mode: "non_inventory",
      default_standard_department: @department,
      pricing_method: "fixed"
    )
    variant = create_standard_variant(klass)
    InventoryBalance.create!(
      store: @store,
      product_variant: variant,
      on_hand_quantity: 0,
      inventory_value_cents: 0
    )

    klass.inventory_mode = "inventory"
    assert_not klass.valid?
    assert_includes klass.errors[:inventory_mode],
                    "cannot change inventory tracking method after inventory history exists"
  end

  test "inventory_mode may change when no variant has history" do
    klass = merchandise_class(
      code: "cls_no_hist",
      default_standard_department: @department,
      pricing_method: "fixed"
    )
    create_standard_variant(klass)

    klass.update!(inventory_mode: "non_inventory")
    assert_equal "non_inventory", klass.reload.inventory_mode

    klass.update!(inventory_mode: "inventory")
    assert_equal "inventory", klass.reload.inventory_mode
  end

  private

  def create_standard_variant(klass)
    product = Products::Create.call(
      attributes: { name: "Class tracking #{klass.code}", status: "active" },
      actor: @actor,
      identifier_mode: "generate"
    )
    ProductVariants::Create.call(
      product: product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: klass.id,
        department_id: @department.id,
        tax_class_id: @tax.id,
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
