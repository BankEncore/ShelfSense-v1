# frozen_string_literal: true

require "test_helper"

class PurchasingCrossLinksTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "xlink_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Crosslink Book")
    @supplier = Supplier.create!(name: "Xlink Supp", code: "xlink_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 600,
      organization_preferred: true
    )
    @customer = Customer.create!(display_name: "Crosslink Customer", email: "cross@example.com")
    @customer_request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    @order = @customer_request.orders.first
    @po = @order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: @po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: @po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    @po_line = @po.purchase_order_lines.first
    @receipt = draft_receipt_with_line(@po_line, received_quantity: 1, actual_unit_cost_cents: 600)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: @receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    @limited_role = Role.create!(
      key: "orders_only_#{SecureRandom.hex(3)}",
      name: "Orders only",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    %w[orders.view purchase_receipts.view].each do |key|
      RolePermission.create!(
        role: @limited_role,
        permission: Permission.find_by!(key: key),
        granted_by: @actor
      )
    end
    @limited_user = User.create!(
      username: "orders_only_#{SecureRandom.hex(3)}",
      display_name: "Orders Only",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: @limited_user,
      role: @limited_role,
      store: @store,
      assigned_by: @actor,
      effective_at: Time.current
    )
  end

  test "limited user sees order and PO links but not customer request link on receipt show" do
    sign_in_as(@limited_user)
    post store_selection_path, params: { store_id: @store.id }

    get admin_purchase_receipt_path(@receipt)
    assert_response :success
    assert_match admin_order_path(@order), response.body
    assert_match admin_purchase_order_path(@po), response.body
    assert_no_match admin_customer_request_path(@customer_request), response.body

    get admin_customer_request_path(@customer_request)
    assert_redirected_to root_path
  end

  test "admin sees customer request cross-link on order show" do
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get admin_order_path(@order)
    assert_response :success
    assert_match admin_customer_request_path(@customer_request), response.body
    assert_match admin_purchase_order_path(@po), response.body
  end

  test "multi-line receipt show evaluates store permissions a bounded number of times" do
    variants = Array.new(4) do |i|
      pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Bound Book #{i}")
    end
    variants.each do |variant|
      SupplierVariantSource.create!(
        supplier: @supplier,
        product_variant: variant,
        pricing_method: "direct_unit_cost",
        expected_unit_cost_cents: 250,
        organization_preferred: true
      )
    end

    first_order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: variants.first,
      actor: @actor,
      quantity: 1,
      supplier: @supplier
    )
    po = first_order.purchase_order
    variants.drop(1).each do |variant|
      Purchasing::CreateStockOrder.call(
        store: @store,
        product_variant: variant,
        actor: @actor,
        quantity: 1,
        supplier: @supplier
      )
    end
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po.reload, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )

    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    po.purchase_order_lines.find_each do |line|
      Purchasing::AddPurchaseReceiptLine.call(
        purchase_receipt: receipt.reload,
        purchase_order_line: line,
        actor: @actor,
        received_quantity: 1,
        actual_unit_cost_cents: 250
      )
    end
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt.reload,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    store_evaluations = Hash.new(0)
    original = Authorization::PermissionEvaluator.method(:permissions_for)
    Authorization::PermissionEvaluator.define_singleton_method(:permissions_for) do |user:, store:|
      store_evaluations[store&.id || :global] += 1
      original.call(user: user, store: store)
    end

    begin
      get admin_purchase_receipt_path(receipt)
      assert_response :success
      assert_operator receipt.purchase_receipt_lines.count, :>=, 4
      # Cross-link helpers share one memoized permission set per store for the render.
      # Allow a small constant for layout/current-store effective_permissions plus hub nav.
      assert_operator store_evaluations[@store.id], :<=, 3
      assert_operator store_evaluations[@store.id], :>=, 1
    ensure
      Authorization::PermissionEvaluator.define_singleton_method(:permissions_for, original)
    end
  end

  private

  def sign_in_as(user_or_username)
    username = user_or_username.is_a?(User) ? user_or_username.username : user_or_username
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def draft_receipt_with_line(po_line, received_quantity:, actual_unit_cost_cents:)
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: po_line,
      actor: @actor,
      received_quantity: received_quantity,
      actual_unit_cost_cents: actual_unit_cost_cents
    )
    receipt.reload
  end
end
