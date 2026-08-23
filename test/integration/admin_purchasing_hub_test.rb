# frozen_string_literal: true

require "test_helper"

class AdminPurchasingHubTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "hub_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Hub Book")
    @supplier = Supplier.create!(name: "Hub Supp", code: "hub_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
  end

  test "admin hub shows authorized sections with zero counts and operational links when work exists" do
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1,
      supplier: @supplier
    )
    po = order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )

    get admin_purchasing_path
    assert_response :success
    assert_match(/Requests awaiting location/, response.body)
    assert_match(/Draft purchase orders/, response.body)
    assert_match(/Sent purchase orders awaiting receipt/, response.body)
    assert_match(/Receipt drafts in progress/, response.body)
    assert_match(/None awaiting/, response.body)
    assert_match(/1 item/, response.body)
    assert_match(/Sent purchase orders awaiting receipt/, response.body)
    assert_match admin_purchase_orders_path(status: "sent"), response.body
  end

  test "hub without store shows selection prompt and history without operational counts" do
    second_store = Store.create!(
      store_number: "9",
      code: "hub_second",
      name: "Second Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    sign_in_as("admin")
    # Clear implicit single-store selection by having two accessible stores and no session store.
    get admin_purchasing_path
    assert_response :success
    assert_match(/Select a store to view purchasing work/i, response.body)
    assert_no_match(/Active work/i, response.body)
    assert_match(/View all orders/, response.body)
  end

  test "narrow receiving user sees only receipt draft section" do
    role = Role.create!(
      key: "receiving_only_#{SecureRandom.hex(3)}",
      name: "Receiving only",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    %w[purchase_receipts.manage purchase_receipts.view].each do |key|
      RolePermission.create!(
        role: role,
        permission: Permission.find_by!(key: key),
        granted_by: @actor
      )
    end
    user = User.create!(
      username: "recv_only_#{SecureRandom.hex(3)}",
      display_name: "Receiving Only",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: @store,
      assigned_by: @actor,
      effective_at: Time.current
    )

    post session_path, params: { session: { username: user.username, password: "correct-horse-battery" } }
    post store_selection_path, params: { store_id: @store.id }

    get admin_purchasing_path
    assert_response :success
    assert_match(/Receipt drafts in progress/, response.body)
    assert_no_match(/Requests awaiting location/, response.body)
    assert_no_match(/Draft purchase orders/, response.body)
    assert_no_match(/Sent purchase orders awaiting receipt/, response.body)
  end

  test "hub denied without purchasing permissions" do
    role = Role.create!(
      key: "inventory_only_#{SecureRandom.hex(3)}",
      name: "Inventory only",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "inventory.view"),
      granted_by: @actor
    )
    user = User.create!(
      username: "inv_only_#{SecureRandom.hex(3)}",
      display_name: "Inventory Only",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: @store,
      assigned_by: @actor,
      effective_at: Time.current
    )

    post session_path, params: { session: { username: user.username, password: "correct-horse-battery" } }
    get admin_purchasing_path
    assert_redirected_to root_path
  end

  test "flat nav includes purchasing link when hub eligible" do
    sign_in_as("admin")
    get root_path
    assert_response :success
    assert_match admin_purchasing_path, response.body
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
