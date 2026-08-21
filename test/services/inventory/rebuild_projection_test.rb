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
    @department = department(code: "reb_dept")
    @klass = merchandise_class(
      code: "reb_std",
      department: @department,
      pricing_method: "fixed"
    )
    @product = Products::Create.call(
      attributes: { name: "Rebuild Widget", status: "active" },
      actor: @actor
    )
    @variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @klass.id,
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

  test "missing valuation is drift and blocks rebuild" do
    post_opening
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    before = balance.attributes.slice("on_hand_quantity", "inventory_value_cents")
    valuation = InventoryValuationEntry.find_by!(store: @store, product_variant: @variant)
    valuation.destroy!

    kinds = reconcile_kinds
    assert_includes kinds, "missing_valuation"

    error = assert_raises(Inventory::RebuildProjection::Error) { rebuild! }
    assert_match(/pair integrity/i, error.message)
    assert_equal before, balance.reload.attributes.slice("on_hand_quantity", "inventory_value_cents")
  end

  test "missing physical is drift and blocks rebuild" do
    post_opening
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    before = balance.attributes.slice("on_hand_quantity", "inventory_value_cents")
    ledger = InventoryLedgerEntry.find_by!(store: @store, product_variant: @variant)
    ledger.destroy!

    kinds = reconcile_kinds
    assert_includes kinds, "missing_physical"

    error = assert_raises(Inventory::RebuildProjection::Error) { rebuild! }
    assert_match(/pair integrity/i, error.message)
    assert_equal before, balance.reload.attributes.slice("on_hand_quantity", "inventory_value_cents")
  end

  test "mismatched pair quantity is drift and blocks rebuild" do
    post_opening
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    before = balance.attributes.slice("on_hand_quantity", "inventory_value_cents")
    valuation = InventoryValuationEntry.find_by!(store: @store, product_variant: @variant)
    valuation.update_columns(quantity_delta: 99)

    kinds = reconcile_kinds
    assert_includes kinds, "pair_mismatch"

    error = assert_raises(Inventory::RebuildProjection::Error) { rebuild! }
    assert_match(/pair integrity/i, error.message)
    assert_equal before, balance.reload.attributes.slice("on_hand_quantity", "inventory_value_cents")
  end

  test "valuation-only history without a balance is reported" do
    InventoryValuationEntry.create!(
      store: @store,
      product_variant: @variant,
      quantity_delta: 5,
      value_delta_cents: 500,
      valuation_method: "moving_average",
      entry_type: "acquisition",
      source_type: "InventoryAdjustment",
      source_id: SecureRandom.uuid_v7,
      effect_sequence: 0,
      business_date: Date.current,
      occurred_at: Time.current
    )

    kinds = reconcile_kinds
    assert_includes kinds, "missing_physical"
    assert_includes kinds, "missing_balance"

    error = assert_raises(Inventory::RebuildProjection::Error) { rebuild! }
    assert_match(/pair integrity/i, error.message)
    assert_nil InventoryBalance.find_by(store: @store, product_variant: @variant)
  end

  private

  def post_opening
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
  end

  def rebuild!
    Inventory::RebuildProjection.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
  end

  def reconcile_kinds
    Inventory::Reconcile.call(store: @store).select { |d| d.product_variant_id == @variant.id }.map(&:kind)
  end
end
