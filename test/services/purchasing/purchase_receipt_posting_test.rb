# frozen_string_literal: true

require "test_helper"

class Purchasing::PurchaseReceiptPostingTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "recv_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Receivable Book")
    @supplier = Supplier.create!(name: "Ingram Receive", code: "igr_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    @other_supplier = Supplier.create!(name: "Baker Receive", code: "bkr_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @other_supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 550
    )
    @customer = Customer.create!(display_name: "Alex Reader", email: "alex@example.com")
  end

  test "post receipt increases on-hand and value with moving average" do
    seed_balance!(on_hand: 2, value_cents: 800)
    po_line = sent_stock_line(quantity: 3)

    receipt = draft_receipt_with_line(po_line, received_quantity: 3, actual_unit_cost_cents: 600)
    assert_nil receipt.number

    posted = Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_equal "posted", posted.status
    assert_equal 1, posted.number
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 5, balance.on_hand_quantity
    assert_equal 800 + (3 * 600), balance.inventory_value_cents
    assert OutboxMessage.exists?(event_type: "inventory.receipt_posted")
    assert OutboxMessage.exists?(event_type: "purchasing.receipt_posted", aggregate_id: posted.id)
  end

  test "ancillary charges do not enter inventory value" do
    seed_balance!(on_hand: 0, value_cents: 0)
    po_line = sent_stock_line(quantity: 2)

    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor,
      freight_cents: 1_000,
      handling_cents: 250,
      supplier_tax_cents: 100,
      miscellaneous_charges_cents: 50,
      charge_notes: "pallet fee"
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: po_line,
      actor: @actor,
      received_quantity: 2,
      actual_unit_cost_cents: 400
    )

    posted = Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt.reload,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance.on_hand_quantity
    assert_equal 800, balance.inventory_value_cents
    assert_equal 1_400, posted.ancillary_total_cents
    assert_equal 800, posted.merchandise_total_cents
  end

  test "partial receipt and over-shipment freeze matched and unplanned" do
    po_line = sent_stock_line(quantity: 5)

    partial = draft_receipt_with_line(po_line, received_quantity: 2, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: partial,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = partial.purchase_receipt_lines.first.reload
    assert_equal 2, line.matched_quantity
    assert_equal 0, line.unplanned_quantity
    assert_equal 3, po_line.reload.open_quantity

    over = draft_receipt_with_line(po_line, received_quantity: 5, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: over,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    over_line = over.purchase_receipt_lines.first.reload
    assert_equal 3, over_line.matched_quantity
    assert_equal 2, over_line.unplanned_quantity
    assert_equal 0, po_line.reload.open_quantity
    assert_equal "closed", po_line.purchase_order.reload.status
  end

  test "special-order receipt creates allocation and marks request available" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Special Receive")
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
    po = request.orders.first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    assert_equal "ordered", request.reload.status
    po_line = po.purchase_order_lines.first

    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 900)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_equal "available", request.reload.status
    allocation = request.active_allocation
    assert allocation.present?
    assert_equal "standard_quantity", allocation.allocation_type
    assert_equal receipt.purchase_receipt_lines.first.id, allocation.purchase_receipt_line_id
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: oos).on_hand_quantity
  end

  test "cancelled request receipt stays stock only" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Cancelled Receive")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 700,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )
    po = request.orders.first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    Customers::CancelRequest.call(
      customer_request: request,
      actor: @actor,
      reason: "customer changed mind"
    )
    assert_equal "cancelled", request.reload.status
    po_line = po.purchase_order_lines.first

    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 700)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_nil request.reload.active_allocation
    assert_equal "cancelled", request.status
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: oos).on_hand_quantity
  end

  test "post is idempotent" do
    po_line = sent_stock_line(quantity: 1)
    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 500)
    key = SecureRandom.uuid_v7

    first = Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: key
    )
    second = Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: key
    )

    assert_equal first.id, second.id
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PurchaseReceiptLine").count
  end

  test "number is assigned at post not draft create" do
    po_line = sent_stock_line(quantity: 1)
    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 500)
    assert_nil receipt.number
    assert_equal 0, StoreDocumentSequence.where(store: @store, document_kind: "purchase_receipt").count

    posted = Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    assert_equal 1, posted.number
    assert_equal 2, StoreDocumentSequence.find_by!(store: @store, document_kind: "purchase_receipt").next_value
  end

  test "multi-PO same supplier allowed and cross-supplier rejected" do
    first_line = sent_stock_line(quantity: 1)

    second_order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1,
      supplier: @supplier
    )
    second_po = second_order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: second_po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: second_po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    second_line = second_po.purchase_order_lines.first

    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: first_line,
      actor: @actor,
      received_quantity: 1,
      actual_unit_cost_cents: 500
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: second_line,
      actor: @actor,
      received_quantity: 1,
      actual_unit_cost_cents: 500
    )
    assert_equal 2, receipt.purchase_receipt_lines.count

    foreign_order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1,
      supplier: @other_supplier
    )
    foreign_po = foreign_order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: foreign_po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: foreign_po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    foreign_line = foreign_po.purchase_order_lines.first

    error = assert_raises(Purchasing::Error) do
      Purchasing::AddPurchaseReceiptLine.call(
        purchase_receipt: receipt,
        purchase_order_line: foreign_line,
        actor: @actor,
        received_quantity: 1,
        actual_unit_cost_cents: 500
      )
    end
    assert_match(/supplier/i, error.message)
  end

  test "update draft receipt audits ancillary charge changes" do
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor,
      freight_cents: 0
    )

    updated = Purchasing::UpdateDraftPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      freight_cents: 250,
      notes: "dock fee",
      expected_lock_version: receipt.lock_version
    )

    assert_equal 250, updated.freight_cents
    assert_equal "dock fee", updated.notes
    event = AuditEvent.where(action: "purchase_receipts.update_draft", subject_id: receipt.id).order(:created_at).last
    assert event
    assert_equal "succeeded", event.outcome
    assert_equal 0, event.before_values["freight_cents"]
    assert_equal 250, event.after_values["freight_cents"]

    posted = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    # Mark as posted via update_columns to avoid full PO setup for rejection path
    posted.update_columns(status: "posted", number: 99, posted_at: Time.current, updated_at: Time.current)
    error = assert_raises(Purchasing::Error) do
      Purchasing::UpdateDraftPurchaseReceipt.call(
        purchase_receipt: posted,
        actor: @actor,
        freight_cents: 1
      )
    end
    assert_match(/draft/i, error.message)
  end

  private

  def seed_balance!(on_hand:, value_cents:)
    InventoryBalance.create!(
      store: @store,
      product_variant: @variant,
      on_hand_quantity: on_hand,
      inventory_value_cents: value_cents
    )
  end

  def sent_stock_line(quantity:)
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: quantity,
      supplier: @supplier
    )
    po = order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    sent = Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    raise "expected sent PO, got #{sent.status}" unless sent.sent?
    line = sent.purchase_order_lines.first
    raise "line PO not sent" unless line.purchase_order.reload.sent?
    line
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
