# frozen_string_literal: true

require "test_helper"

class Phase7StoreAuthzTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @east = Store.create!(
      store_number: "2",
      code: "east_p7",
      name: "East Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    Inventory::AdjustmentReasons.seed!

    role = Role.find_by!(key: "store_manager")
    %w[purchase_receipts.correct purchase_receipts.compensate].each do |key|
      permission = Permission.find_by!(key: key)
      RolePermission.find_or_create_by!(role: role, permission: permission) do |rp|
        rp.granted_by = @admin
      end
    end

    @manager = User.create!(
      username: "p7_manager",
      display_name: "P7 Store Manager",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: @manager,
      role: role,
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )

    @tax = tax_class(code: "p7a_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @admin, tax_class: @tax, name: "East Authz Book")
    @supplier = Supplier.create!(name: "East Supp", code: "es_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400,
      organization_preferred: true
    )
    @customer = Customer.create!(display_name: "East Customer", email: "east@example.com")

    @east_order = Purchasing::CreateStockOrder.call(
      store: @east,
      product_variant: @variant,
      actor: @admin,
      quantity: 2
    )
    @east_po = @east_order.purchase_order
    @east_po_line = @east_order.purchase_order_line

    @east_request = Customers::CreateRequest.call(
      store: @east,
      customer: @customer,
      product_variant: @variant,
      actor: @admin
    )

    Purchasing::GeneratePurchaseOrder.call(purchase_order: @east_po, actor: @admin)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: @east_po.reload,
      actor: @admin,
      transmission_method: "email"
    )
    @east_receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @east,
      supplier: @supplier,
      actor: @admin
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: @east_receipt,
      purchase_order_line: @east_po_line.reload,
      actor: @admin,
      received_quantity: 1,
      actual_unit_cost_cents: 400
    )
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: @east_receipt,
      actor: @admin,
      idempotency_key: SecureRandom.uuid_v7
    )
    @east_receipt_line = @east_receipt.purchase_receipt_lines.first
  end

  test "store-scoped manager cannot show another store's order or purchase order" do
    sign_in_as("p7_manager")
    post store_selection_path, params: { store_id: @store.id }

    get admin_order_path(@east_order)
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied").order(:created_at).last.outcome

    get admin_purchase_order_path(@east_po)
    assert_redirected_to root_path
  end

  test "store-scoped manager cannot cancel another store's PO line" do
    sign_in_as("p7_manager")
    post store_selection_path, params: { store_id: @store.id }

    assert_no_difference -> { PurchaseOrderLineCancellation.count } do
      post cancel_line_admin_purchase_order_path(@east_po, line_id: @east_po_line.id), params: {
        quantity: 1,
        reason: "cross-store cancel",
        source: "buyer"
      }
    end
    assert_redirected_to root_path
    assert_equal 1, @east_po_line.reload.open_quantity
  end

  test "store-scoped manager cannot show or cancel another store's customer request" do
    sign_in_as("p7_manager")
    post store_selection_path, params: { store_id: @store.id }

    get admin_customer_request_path(@east_request)
    assert_redirected_to root_path

    status_before = @east_request.reload.status
    post cancel_admin_customer_request_path(@east_request), params: {
      cancellation_reason: "cross-store",
      lock_version: @east_request.lock_version
    }
    assert_redirected_to root_path
    assert_equal status_before, @east_request.reload.status
    assert_not_equal "cancelled", @east_request.status
  end

  test "store-scoped manager cannot show or reverse another store's receipt" do
    sign_in_as("p7_manager")
    post store_selection_path, params: { store_id: @store.id }

    get admin_purchase_receipt_path(@east_receipt)
    assert_redirected_to root_path

    assert_no_difference -> { PurchaseReceiptLineCorrection.count } do
      post reverse_line_admin_purchase_receipt_path(@east_receipt, line_id: @east_receipt_line.id), params: {
        reason: "cross-store reverse",
        idempotency_key: SecureRandom.uuid_v7
      }
    end
    assert_redirected_to root_path
    assert_equal 1, @east_receipt_line.reload.remaining_reversible_quantity

    assert_no_difference -> { PurchaseReceiptLineCorrection.count } do
      post correct_cost_admin_purchase_receipt_path(@east_receipt, line_id: @east_receipt_line.id), params: {
        reason: "cross-store cost",
        corrected_unit_cost_cents: 450,
        idempotency_key: SecureRandom.uuid_v7
      }
    end
    assert_redirected_to root_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
