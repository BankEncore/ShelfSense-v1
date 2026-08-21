# frozen_string_literal: true

require "test_helper"

class ProductInventoryDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @actor = @admin
    Inventory::AdjustmentReasons.seed!

    @tax = tax_class(code: "disp_tax")
    @department = department(code: "disp_dept")
    @klass = merchandise_class(
      code: "disp_std",
      department: @department,
      pricing_method: "fixed"
    )
    @used_klass = merchandise_class(
      code: "disp_used",
      used_merchandise_allowed: true,
      department: @department,
            pricing_method: "fixed"
    )
    @condition = merchandise_condition(code: "good")

    @product = Products::Create.call(
      attributes: { name: "Inventory Display Book", status: "active" },
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
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @qty_variant,
      adjustment_reason: @opening,
      quantity_delta: 5,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100
    )
    @unit_adjustment = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @individual_variant,
      adjustment_reason: @opening,
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500,
      regular_price_cents: 900
    )
  end

  test "with inventory.view and current store shows on-hand and units" do
    sign_in_as("admin")

    get admin_products_path
    assert_response :success
    assert_match(/On hand/, response.body)
    assert_match(/>\s*6\s*</, response.body)

    get admin_product_path(@product)
    assert_response :success
    assert_match(/On hand/, response.body)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @qty_variant)
    assert_includes response.body, admin_inventory_balance_path(balance)
    assert_match(/>\s*5\s*</, response.body)

    get admin_product_variant_path(@individual_variant)
    assert_response :success
    assert_match(/Inventory/, response.body)
    assert_match(/On-hand units/, response.body)
    unit = @unit_adjustment.inventory_unit
    assert_match(/#{unit.unit_identifier}/, response.body)
    assert_match(/\$5\.00/, response.body)
  end

  test "without inventory.view omits inventory UI" do
    RolePermission.joins(:permission).where(permissions: { key: "inventory.view" }).find_each(&:destroy)
    sign_in_as("admin")

    get admin_products_path
    assert_response :success
    assert_no_match(/On hand/, response.body)

    get admin_product_path(@product)
    assert_response :success
    assert_no_match(/On hand/, response.body)

    get admin_product_variant_path(@individual_variant)
    assert_response :success
    assert_no_match(/On-hand units/, response.body)
    assert_no_match(/#{@unit_adjustment.inventory_unit.unit_identifier}/, response.body)
  end

  test "without current store omits inventory UI" do
    Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store", legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    sign_in_as("admin")

    get admin_products_path
    assert_response :success
    assert_no_match(/On hand/, response.body)

    get admin_product_path(@product)
    assert_response :success
    assert_no_match(/On hand/, response.body)

    get admin_product_variant_path(@individual_variant)
    assert_response :success
    assert_no_match(/On-hand units/, response.body)
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
