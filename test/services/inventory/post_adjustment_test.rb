# frozen_string_literal: true

require "test_helper"

class InventoryPostAdjustmentTest < ActiveSupport::TestCase
  include Phase2Fixtures

  setup do
    @actor = actor_user
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)

    @tax = tax_class(code: "inv_tax")
    @department = department(code: "inv_dept", default_tax_class: @tax)
    @klass = merchandise_class(
      code: "inv_std",
      default_standard_department: @department,
      pricing_method: "fixed"
    )
    @product = Products::Create.call(
      attributes: { name: "Widget", status: "active" },
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
    @shrinkage = AdjustmentReason.find_by!(code: "shrinkage")
  end

  test "opening quantity inventory establishes quantity and value" do
    adjustment = post_qty(10, 100)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 10, balance.on_hand_quantity
    assert_equal 1_000, balance.inventory_value_cents
    assert_equal 1, InventoryLedgerEntry.where(source_id: adjustment.id).count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.adjustment_posted").count
  end

  test "partial depletion uses half-up proportional value" do
    post_qty(3, 100)
    post_qty(-1, nil, reason: @shrinkage)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance.on_hand_quantity
    assert_equal 200, balance.inventory_value_cents
  end

  test "final depletion clears value exactly" do
    post_qty(3, 100)
    post_qty(-1, nil, reason: @shrinkage)
    post_qty(-2, nil, reason: @shrinkage)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
  end

  test "rejects negative on-hand" do
    post_qty(1, 100)
    error = assert_raises(Inventory::PostAdjustment::Error) { post_qty(-2, nil, reason: @shrinkage) }
    assert_match(/below zero|insufficient/i, error.message)
  end

  test "idempotent retry returns same adjustment" do
    key = SecureRandom.uuid_v7
    source = SecureRandom.uuid_v7
    first = post_qty(2, 50, key: key, source: source)
    second = post_qty(2, 50, key: key, source: source)
    assert_equal first.id, second.id
    assert_equal 1, InventoryAdjustment.where(product_variant: @variant).count
  end

  test "payload mismatch is an error" do
    key = SecureRandom.uuid_v7
    source = SecureRandom.uuid_v7
    post_qty(2, 50, key: key, source: source)
    assert_raises(Idempotency::OperationService::PayloadMismatchError) do
      post_qty(3, 50, key: key, source: source)
    end
  end

  test "exact reversal negates stored effects" do
    original = post_qty(5, 200)
    reversal = Inventory::ReverseAdjustment.call(
      adjustment: original,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      notes: "mistake"
    )
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
    assert original.reload.reversed?
    assert_equal(-original.quantity_delta, reversal.quantity_delta)
  end

  test "individual acquisition and removal" do
    used_klass = merchandise_class(
      code: "inv_used",
      used_merchandise_allowed: true,
      default_standard_department: @department,
      default_used_department: @department,
      pricing_method: "fixed"
    )
    condition = merchandise_condition(code: "good")
    used = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_klass.id,
        merchandise_condition_id: condition.id,
        department_id: @department.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )

    acquisition = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500,
      regular_price_cents: 900
    )
    unit = acquisition.inventory_unit
    assert unit.on_hand?
    assert_equal 900, unit.regular_price_cents
    assert unit.unit_identifier.start_with?("220")

    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @shrinkage,
      quantity_delta: -1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      unit_identifier: unit.unit_identifier
    )
    assert unit.reload.removed?
    balance = InventoryBalance.find_by!(store: @store, product_variant: used)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
  end

  test "individual removal rejects missing unit identifier" do
    used_klass = merchandise_class(
      code: "inv_used_miss",
      used_merchandise_allowed: true,
      default_standard_department: @department,
      default_used_department: @department,
      pricing_method: "fixed"
    )
    condition = merchandise_condition(code: "good")
    used = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_klass.id,
        merchandise_condition_id: condition.id,
        department_id: @department.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500
    )

    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: used,
        adjustment_reason: @shrinkage,
        quantity_delta: -1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/unit identifier is required/i, error.message)
  end

  private

  def post_qty(delta, cost_cents, reason: @opening, key: SecureRandom.uuid_v7, source: SecureRandom.uuid_v7)
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: reason,
      quantity_delta: delta,
      actor: @actor,
      source_id: source,
      idempotency_key: key,
      acquisition_unit_cost_cents: cost_cents
    )
  end
end
