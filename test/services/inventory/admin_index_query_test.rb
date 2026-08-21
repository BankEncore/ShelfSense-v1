# frozen_string_literal: true

require "test_helper"

class Inventory::AdminIndexQueryTest < ActiveSupport::TestCase
  include Phase2Fixtures

  setup do
    @actor = actor_user
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)

    @tax = tax_class(code: "idx_tax")
    @department = department(code: "idx_dept")
    @qty_class = merchandise_class(
      code: "idx_qty",
      department: @department,
      pricing_method: "fixed"
    )
    @used_class = merchandise_class(
      code: "idx_used",
      used_merchandise_allowed: true,
      department: @department,
            pricing_method: "fixed"
    )
    @condition = merchandise_condition(code: "idx_good")
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")

    @product = Products::Create.call(
      attributes: { name: "Index Widget", status: "active" },
      actor: @actor
    )
    @qty_variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @qty_class.id,
        regular_price_cents: 1999
      },
      actor: @actor
    )
    @used_variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: @used_class.id,
        merchandise_condition_id: @condition.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )

    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @qty_variant,
      adjustment_reason: @opening,
      quantity_delta: 2,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100
    )
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @used_variant,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500
    )
  end

  test "filters derived tracking in SQL and paginates" do
    quantity = Inventory::AdminIndexQuery.call(store_ids: [ @store.id ], tracking: "quantity")
    assert_equal 1, quantity.total_count
    assert_equal [ @qty_variant.id ], quantity.records.map(&:product_variant_id)

    individual = Inventory::AdminIndexQuery.call(store_ids: [ @store.id ], tracking: "individual")
    assert_equal 1, individual.total_count
    assert_equal [ @used_variant.id ], individual.records.map(&:product_variant_id)

    all = Inventory::AdminIndexQuery.call(store_ids: [ @store.id ], page: 1)
    assert_equal 2, all.total_count
    assert_equal 1, all.total_pages
    assert_equal 2, all.records.size
  end
end
