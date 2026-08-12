# frozen_string_literal: true

require "test_helper"

class Inventory::RebuildProjectionTest < ActiveSupport::TestCase
  include Phase2Fixtures

  setup do
    @actor = actor_user
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)

    @tax = tax_class(code: "reb_tax")
    @department = department(code: "reb_dept", default_tax_class: @tax)
    @klass = merchandise_class(
      code: "reb_std",
      default_standard_department: @department,
      pricing_method: "fixed"
    )
    @product = Products::Create.call(
      attributes: { name: "Rebuild Widget", status: "active" },
      actor: @actor,
      identifier_mode: "generate"
    )
    @variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @klass.id,
        department_id: @department.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1999
      },
      actor: @actor
    )
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
  end

  test "reconcile detects drift and rebuild repairs the projection" do
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: @opening,
      quantity_delta: 5,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100
    )
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    balance.update_columns(on_hand_quantity: 99, inventory_value_cents: 1)

    drifts = Inventory::Reconcile.call(store: @store)
    kinds = drifts.select { |d| d.product_variant_id == @variant.id }.map(&:kind)
    assert_includes kinds, "quantity"
    assert_includes kinds, "value"

    Inventory::RebuildProjection.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    balance.reload
    assert_equal 5, balance.on_hand_quantity
    assert_equal 500, balance.inventory_value_cents
    remaining = Inventory::Reconcile.call(store: @store).select { |d| d.product_variant_id == @variant.id }
    assert_empty remaining
  end
end
