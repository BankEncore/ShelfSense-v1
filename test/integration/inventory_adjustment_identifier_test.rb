# frozen_string_literal: true

require "test_helper"

class InventoryAdjustmentIdentifierTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @actor = @admin
    Inventory::AdjustmentReasons.seed!

    @tax = tax_class(code: "adj_id_tax")
    @department = department(code: "adj_id_dept")
    @klass = merchandise_class(
      code: "adj_id_std",
      department: @department,
      pricing_method: "fixed"
    )
    @used_klass = merchandise_class(
      code: "adj_id_used",
      used_merchandise_allowed: true,
      department: @department,
            pricing_method: "fixed"
    )
    @condition = merchandise_condition(code: "good")

    @product = Products::Create.call(
      attributes: { name: "Adjustment Identifier Book", status: "active" },
      actor: @actor
    )
    @qty_variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @klass.id,
        regular_price_cents: 1999
      },
      actor: @actor
    )
    @individual_variant = ProductVariants::Create.call(
      product: @product,
      attributes: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: @used_klass.id,
        merchandise_condition_id: @condition.id,
        regular_price_cents: 1200
      },
      actor: @actor
    )
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
    @shrinkage = AdjustmentReason.find_by!(code: "shrinkage")
  end

  test "adjustment form is a full page post without turbo" do
    sign_in_as("admin")

    get new_admin_inventory_adjustment_path
    assert_response :success
    assert_select "html[data-turbo=false]"
    assert_select "script[type=module]", text: /import "application"/
    assert_select "script[type=module]", text: /import "pos"/, count: 0
  end

  test "posts quantity adjustment using variant SKU" do
    sign_in_as("admin")

    post preview_admin_inventory_adjustments_path, params: {
      store_id: @store.id,
      product_variant_id: @qty_variant.sku,
      adjustment_reason_id: @opening.id,
      quantity_delta: 3,
      acquisition_unit_cost: "2.00",
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_response :success
    assert_match(/Confirm adjustment/, response.body)

    post admin_inventory_adjustments_path, params: {
      store_id: @store.id,
      product_variant_id: @qty_variant.sku,
      adjustment_reason_id: @opening.id,
      quantity_delta: 3,
      acquisition_unit_cost: "2.00",
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_response :redirect
    balance = InventoryBalance.find_by!(store: @store, product_variant: @qty_variant)
    assert_equal 3, balance.on_hand_quantity
    assert_equal 600, balance.inventory_value_cents
  end

  test "removes individual unit by unit identifier" do
    acquisition = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @individual_variant,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500
    )
    unit = acquisition.inventory_unit

    sign_in_as("admin")
    get new_admin_inventory_adjustment_path(
      store_id: @store.id,
      product_variant_id: @individual_variant.id
    )
    assert_response :success
    assert_match(/Variant identifier/, response.body)
    assert_match(/Unit identifier/, response.body)
    assert_no_match(/inventory_unit_id/, response.body)
    assert_match(/#{unit.unit_identifier}/, response.body)

    post admin_inventory_adjustments_path, params: {
      store_id: @store.id,
      product_variant_id: @individual_variant.sku,
      adjustment_reason_id: @shrinkage.id,
      quantity_delta: -1,
      unit_identifier: unit.unit_identifier,
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_response :redirect
    assert unit.reload.removed?
  end

  test "adjustment matching accepts a product whose only variant POS would refuse" do
    product = Products::Create.call(
      attributes: { name: "Not For Sale Yet", status: "draft" },
      actor: @actor,
      lookup_code: "adj-draft"
    )
    variant = ProductVariants::Create.call(
      product: product,
      attributes: { variant_type: "standard", status: "draft", merchandise_class_id: @klass.id },
      actor: @actor
    )
    assert_not variant.sellable?

    sign_in_as("admin")
    post preview_admin_inventory_adjustments_path, params: {
      store_id: @store.id,
      product_variant_id: "adj-draft",
      adjustment_reason_id: @opening.id,
      quantity_delta: 2,
      acquisition_unit_cost: "1.00",
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }

    assert_response :success
    assert_match(/Confirm adjustment/, response.body)

    post admin_inventory_adjustments_path, params: {
      store_id: @store.id,
      product_variant_id: "adj-draft",
      adjustment_reason_id: @opening.id,
      quantity_delta: 2,
      acquisition_unit_cost: "1.00",
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_response :redirect
    assert_equal 2, InventoryBalance.find_by!(store: @store, product_variant: variant).on_hand_quantity
  end

  test "adjustment matching refuses a shared lookup code instead of picking one product" do
    first = Products::Create.call(
      attributes: { name: "Shared A", status: "active" },
      actor: @actor,
      lookup_code: "adj-shared"
    )
    second = Products::Create.call(
      attributes: { name: "Shared B", status: "active" },
      actor: @actor,
      lookup_code: "adj-shared"
    )
    [ first, second ].each do |product|
      ProductVariants::Create.call(
        product: product,
        attributes: { variant_type: "standard", status: "active", merchandise_class_id: @klass.id, regular_price_cents: 500 },
        actor: @actor
      )
    end

    sign_in_as("admin")
    post preview_admin_inventory_adjustments_path, params: {
      store_id: @store.id,
      product_variant_id: "adj-shared",
      adjustment_reason_id: @opening.id,
      quantity_delta: 2,
      acquisition_unit_cost: "1.00",
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }

    assert_response :redirect
    follow_redirect!
    assert_match(/Multiple products share that lookup code/, response.body)
    assert_no_match(/Confirm adjustment/, response.body)
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
