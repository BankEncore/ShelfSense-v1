# frozen_string_literal: true

require "test_helper"

class InventoryStoreAuthzTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @east = Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )
    Inventory::AdjustmentReasons.seed!

    @manager = User.create!(
      username: "manager",
      display_name: "Store Manager",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: @manager,
      role: Role.find_by!(key: "store_manager"),
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )

    @tax = tax_class(code: "authz_tax")
    @department = department(code: "authz_dept", default_tax_class: @tax)
    @klass = merchandise_class(
      code: "authz_std",
      default_standard_department: @department,
      pricing_method: "fixed"
    )
    @product = Products::Create.call(
      attributes: { name: "Authz Widget", status: "active" },
      actor: @admin,
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
      actor: @admin
    )
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
    @east_adjustment = Inventory::PostAdjustment.call(
      store: @east,
      product_variant: @variant,
      adjustment_reason: @opening,
      quantity_delta: 2,
      actor: @admin,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 100
    )
    @east_balance = InventoryBalance.find_by!(store: @east, product_variant: @variant)
  end

  test "store-scoped manager cannot preview or post another store's inventory" do
    sign_in_as("manager")

    post preview_admin_inventory_adjustments_path, params: adjustment_params(@east)
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied").order(:created_at).last.outcome

    post admin_inventory_adjustments_path, params: adjustment_params(@east)
    assert_redirected_to root_path
    assert_equal 1, InventoryAdjustment.where(store: @east).count
  end

  test "store-scoped manager cannot show or reverse another store's adjustment" do
    sign_in_as("manager")

    get admin_inventory_adjustment_path(@east_adjustment)
    assert_redirected_to root_path

    get reverse_admin_inventory_adjustment_path(@east_adjustment)
    assert_redirected_to root_path

    post reverse_admin_inventory_adjustment_path(@east_adjustment), params: {
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      notes: "cross-store reverse"
    }
    assert_redirected_to root_path
    assert_not @east_adjustment.reload.reversed?
  end

  test "store-scoped manager cannot show another store's balance" do
    sign_in_as("manager")

    get admin_inventory_balance_path(@east_balance)
    assert_redirected_to root_path
  end

  test "rebuild is denied for another store" do
    sign_in_as("manager")

    get rebuild_admin_inventory_balance_path(@east_balance)
    assert_redirected_to root_path

    post rebuild_admin_inventory_balance_path(@east_balance), params: {
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to root_path
  end

  test "store-scoped manager may preview their own store" do
    sign_in_as("manager")

    post preview_admin_inventory_adjustments_path, params: adjustment_params(@store)
    assert_response :success
    assert_match(/Confirm adjustment/, response.body)
  end

  test "reconcile requires inventory.reconcile" do
    sign_in_as("manager")
    get admin_inventory_reconciliation_path
    assert_redirected_to root_path

    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }
    follow_redirect!
    get admin_inventory_reconciliation_path
    assert_response :success
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end

  def adjustment_params(store)
    {
      store_id: store.id,
      product_variant_id: @variant.sku,
      adjustment_reason_id: @opening.id,
      quantity_delta: 1,
      acquisition_unit_cost: "1.00",
      command_token: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    }
  end
end
