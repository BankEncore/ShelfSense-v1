# frozen_string_literal: true

require "test_helper"

class PurchaseOrdersAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "poi_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Admin PO")
    @supplier = Supplier.create!(name: "Admin PO Supp", code: "aps_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300,
      organization_preferred: true
    )
  end

  test "generate send and filter purchase orders" do
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 2,
      supplier: @supplier
    )
    po = order.purchase_order

    get ops_purchase_order_path(po)
    assert_response :success
    assert_match(/Generate PO number/, response.body)

    post ops_purchase_order_generate_path(po), params: { lock_version: po.lock_version }
    assert_redirected_to ops_purchase_order_path(po)
    po.reload
    assert_equal 1, po.number

    post ops_purchase_order_send_path(po), params: {
      lock_version: po.lock_version,
      transmission_method: "email"
    }
    assert_redirected_to admin_purchase_order_path(po)
    assert_equal "sent", po.reload.status

    get admin_purchase_orders_path(status: "sent")
    assert_response :success
    assert_match(/PO ##{po.number}/, response.body)

    get admin_purchase_order_path(po)
    assert_response :success
    assert_select "button", text: "Review cancellation"
    assert_match(/Acknowledgment/, response.body)
  end

  test "show summarizes multiple lines and distinguishes missing acknowledgment from confirmed zero" do
    po, first_line, second_line = sent_multi_line_purchase_order
    Purchasing::RecordLineAcknowledgment.call(
      purchase_order_line: first_line,
      actor: @actor,
      confirmed_quantity: 0,
      backordered_quantity: 2,
      expected_on: Date.current - 1,
      expected_lock_version: first_line.line_state.lock_version
    )

    sign_in_as("admin")
    select_store
    get admin_purchase_order_path(po)

    assert_response :success
    assert_select "table.purchase-order-lines__table tbody tr[data-purchase-order-line-id]", count: 2
    assert_select "#purchase-order-line-#{first_line.id}", text: /Confirmed 0/
    assert_select "#purchase-order-line-#{second_line.id} .status-badge", text: "Not acknowledged"
    assert_select ".purchase-order-summary", text: /Open quantity\s*5/
    assert_select ".purchase-order-summary", text: /Confirmed quantity\s*0/
    assert_select ".purchase-order-summary", text: /Backordered quantity\s*2/
    assert_select ".purchase-order-summary", text: /Overdue acknowledged lines\s*1/
    assert_select ".purchase-order-summary", text: /Expected merchandise value\s*\$15\.00/
    refute_match(/nil/, response.body)
  end

  test "permission-specific line controls are hidden while acknowledgment facts remain visible" do
    po, first_line, = sent_multi_line_purchase_order
    Purchasing::RecordLineAcknowledgment.call(
      purchase_order_line: first_line,
      actor: @actor,
      confirmed_quantity: 1,
      expected_lock_version: first_line.line_state.lock_version
    )
    viewer = create_store_viewer

    sign_in_as(viewer.username)
    select_store
    get admin_purchase_order_path(po)

    assert_response :success
    assert_select "#purchase-order-line-#{first_line.id}", text: /Confirmed 1/
    assert_select "button", text: "Edit acknowledgment", count: 0
    assert_select "button", text: "Review cancellation", count: 0
  end

  test "invalid and stale acknowledgments render the affected dialog with current lock and submitted values" do
    po, line, = sent_multi_line_purchase_order
    sign_in_as("admin")
    select_store

    patch acknowledge_line_admin_purchase_order_path(po, line_id: line.id), params: {
      lock_version: line.line_state.lock_version,
      confirmed_quantity: "bad",
      backordered_quantity: 2
    }
    assert_response :unprocessable_entity
    assert_select "#purchase-order-line-#{line.id} [data-controller='review-dialog'][data-review-dialog-open-value='true']"
    assert_select "#acknowledgment-dialog-#{line.id} input[name='confirmed_quantity'][value='bad']"

    stale_version = line.line_state.reload.lock_version
    line.line_state.update!(notes: "concurrent")
    patch acknowledge_line_admin_purchase_order_path(po, line_id: line.id), params: {
      lock_version: stale_version,
      confirmed_quantity: 0,
      backordered_quantity: 1
    }
    assert_response :unprocessable_entity
    assert_select "#acknowledgment-dialog-#{line.id}[open]", count: 0
    assert_select "#acknowledgment-dialog-#{line.id} input[name='lock_version'][value='#{line.line_state.reload.lock_version}']"
    assert_select "#acknowledgment-dialog-#{line.id}", text: /changed by someone else/
  end

  test "show preloads receipt and cancellation graphs without per-line queries" do
    po, first_line, = sent_multi_line_purchase_order
    Purchasing::CancelPurchaseOrderQuantity.call(
      purchase_order_line: first_line,
      actor: @actor,
      quantity: 1,
      source: "buyer",
      reason: "Query regression history"
    )
    sign_in_as("admin")
    select_store
    sql = []
    callback = lambda do |_name, _started, _finished, _id, payload|
      statement = payload[:sql].to_s
      sql << statement if statement.match?(/FROM "(?:purchase_receipt_lines|purchase_receipts|purchase_receipt_line_corrections|purchase_order_line_cancellations)"/)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get admin_purchase_order_path(po)
    end

    assert_response :success
    assert_operator sql.size, :<=, 4, "expected one preload query per receipt/cancellation association, got:\n#{sql.join("\n")}"
    assert_select ".purchase-order-lines__history", text: /Query regression history/
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def select_store
    post store_selection_path, params: { store_id: @store.id }
  end

  def sent_multi_line_purchase_order
    first = Purchasing::CreateStockOrder.call(
      store: @store, product_variant: @variant, actor: @actor, quantity: 2, supplier: @supplier
    )
    second_variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Second Admin PO Book")
    SupplierVariantSource.create!(
      supplier: @supplier, product_variant: second_variant, pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300
    )
    second = Purchasing::CreateStockOrder.call(
      store: @store, product_variant: second_variant, actor: @actor, quantity: 3, supplier: @supplier
    )
    po = first.purchase_order
    assert_equal po, second.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(purchase_order: po.reload, actor: @actor, transmission_method: "email")
    [ po.reload, first.purchase_order_line.reload, second.purchase_order_line.reload ]
  end

  def create_store_viewer
    user = User.create!(
      username: "po_viewer_#{SecureRandom.hex(3)}", display_name: "PO Viewer",
      password: "correct-horse-battery", password_confirmation: "correct-horse-battery"
    )
    role = Role.create!(
      key: "po_viewer_#{SecureRandom.hex(3)}", name: "PO Viewer #{SecureRandom.hex(3)}",
      assignment_scope: "store", system_role: false, active: true
    )
    RolePermission.create!(role: role, permission: Permission.find_by!(key: "orders.view"), granted_by: @actor)
    RoleAssignment.create!(user: user, role: role, store: @store, assigned_by: @actor, effective_at: Time.current)
    user
  end
end
