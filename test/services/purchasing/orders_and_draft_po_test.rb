# frozen_string_literal: true

require "test_helper"

class Purchasing::OrdersAndDraftPoTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "po_tax_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Orderable Book")
    @supplier = Supplier.create!(name: "Ingram", code: "ing_#{SecureRandom.hex(2)}")
    @source = SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 750,
      organization_preferred: true
    )
    @customer = Customer.create!(display_name: "Sam Reader", email: "sam@example.com")
  end

  test "stock order creates order line and draft PO" do
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 3
    )

    assert_equal 1, order.number
    assert_nil order.customer_request_id
    assert_equal 3, order.requested_quantity
    assert_equal @supplier, order.supplier

    line = order.purchase_order_line
    assert line.present?
    assert_equal 3, line.ordered_quantity
    assert_equal 750, line.expected_unit_cost_cents_snapshot

    po = line.purchase_order
    assert_equal "draft", po.status
    assert_nil po.number
    assert_equal @store, po.store
    assert_equal @supplier, po.supplier
  end

  test "second stock order for same supplier reuses open draft PO" do
    first = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1
    )
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Second Title")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: other,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400
    )
    second = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: other,
      actor: @actor,
      quantity: 2,
      supplier: @supplier
    )

    assert_equal first.purchase_order_line.purchase_order_id, second.purchase_order_line.purchase_order_id
    assert_equal 1, PurchaseOrder.draft.where(store: @store, supplier: @supplier).count
  end

  test "at most one open draft PO per store and supplier" do
    Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1
    )
    error = assert_raises(ActiveRecord::RecordNotUnique) do
      PurchaseOrder.create!(
        store: @store,
        supplier: @supplier,
        status: "draft",
        document_revision: 0
      )
    end
    assert_match(/index_purchase_orders_one_open_draft|unique/i, error.message)
  end

  test "special order from OOS Standard request" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "OOS Special")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 900,
      organization_preferred: true
    )

    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )

    assert_equal "special_order_pending", request.status
    order = request.orders.first
    assert order.present?
    assert_equal 1, order.requested_quantity
    assert_equal request, order.customer_request
    assert order.purchase_order_line.present?
    assert_equal "draft", order.purchase_order.status
  end

  test "convert not-located Standard creates special order" do
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1, unit_cost_cents: 100)
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    assert_equal "pending_location", request.status

    Customers::ResolveNotLocated.call(
      customer_request: request,
      actor: @actor,
      convert_to_special_order: true,
      notes: "shelf empty"
    )
    request.reload

    assert_equal "special_order_pending", request.status
    assert request.location_failed_at.present?
    assert_equal "shelf empty", request.location_failure_notes
    order = request.orders.first
    assert order.present?
    assert_equal @supplier, order.supplier
    assert order.purchase_order_line.present?
  end

  test "Used rejected at purchasing boundaries" do
    used, = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Reject")

    stock_error = assert_raises(Purchasing::Error) do
      Purchasing::CreateStockOrder.call(
        store: @store,
        product_variant: used,
        actor: @actor,
        quantity: 1,
        supplier: @supplier,
        expected_unit_cost_cents: 100
      )
    end
    assert_match(/Used/i, stock_error.message)

    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: used,
      actor: @actor
    )
    convert_error = assert_raises(Customers::Error) do
      Customers::ResolveNotLocated.call(
        customer_request: request,
        actor: @actor,
        convert_to_special_order: true
      )
    end
    assert_match(/Used/i, convert_error.message)
  end

  test "scan add creates order not bare line" do
    po = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1
    ).purchase_order

    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Scan Add")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: other,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300
    )

    order = Purchasing::AddStockOrderToDraftPo.call(
      purchase_order: po,
      product_variant: other,
      actor: @actor,
      quantity: 2
    )

    assert_equal po.id, order.purchase_order.id
    assert_equal 2, order.requested_quantity
    assert_equal @supplier, order.supplier
    assert_nil order.customer_request_id
    assert_equal 1, PurchaseOrderLine.where(order_id: order.id).count
    assert_equal 2, po.purchase_order_lines.count
  end

  test "cancel request requires draft order decision when unsent order exists" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Cancel Decision")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )
    order = request.orders.first
    assert order.present?

    omitted = assert_raises(Customers::Error) do
      Customers::CancelRequest.call(
        customer_request: request,
        actor: @actor,
        reason: "customer changed mind"
      )
    end
    assert_equal Customers::CancelRequest::DRAFT_ORDER_DECISION_REQUIRED, omitted.message
    assert_equal "special_order_pending", request.reload.status
    assert_nil order.reload.cancelled_at

    Customers::CancelRequest.call(
      customer_request: request,
      actor: @actor,
      reason: "customer changed mind",
      cancel_draft_order: true
    )
    request.reload
    order.reload
    assert_equal "cancelled", request.status
    assert order.cancelled?
    assert_nil PurchaseOrderLine.find_by(order_id: order.id)
  end

  test "cancel request can keep unsent draft order" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Keep Draft")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )
    order = request.orders.first

    Customers::CancelRequest.call(
      customer_request: request,
      actor: @actor,
      reason: "keep as stock",
      cancel_draft_order: false
    )
    assert_equal "cancelled", request.reload.status
    assert_nil order.reload.cancelled_at
    assert order.purchase_order_line.present?
  end

  test "missing expected cost without source is rejected" do
    bare = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "No Source")
    error = assert_raises(Purchasing::Error) do
      Purchasing::CreateStockOrder.call(
        store: @store,
        product_variant: bare,
        actor: @actor,
        quantity: 1,
        supplier: @supplier
      )
    end
    assert_match(/expected unit cost/i, error.message)
  end

  test "UpdateDraftOrder moves line when supplier changes" do
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 2
    )
    other_supplier = Supplier.create!(name: "Other", code: "oth_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: other_supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 800
    )

    Purchasing::UpdateDraftOrder.call(
      order: order,
      actor: @actor,
      supplier: other_supplier,
      quantity: 5
    )
    order.reload

    assert_equal other_supplier, order.supplier
    assert_equal 5, order.requested_quantity
    assert_equal other_supplier, order.purchase_order.supplier
    assert_equal "draft", order.purchase_order.status
    assert_equal 1, PurchaseOrder.draft.where(store: @store, supplier: other_supplier).count
  end
end
