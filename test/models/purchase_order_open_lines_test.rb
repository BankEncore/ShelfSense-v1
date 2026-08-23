# frozen_string_literal: true

require "test_helper"

class PurchaseOrderOpenLinesTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "open_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Open Qty Book")
    @supplier = Supplier.create!(name: "Open Supp", code: "open_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400,
      organization_preferred: true
    )
  end

  test "with_open_lines matches instance open_quantity for partial receipt and reversal" do
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 2,
      supplier: @supplier
    )
    po = order.purchase_order
    line = po.purchase_order_lines.first
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )

    assert_includes PurchaseOrder.sent.with_open_lines, po
    assert_equal 1, PurchaseOrder.sent.for_store(@store).with_open_lines.count

    receipt = draft_receipt_with_line(line, received_quantity: 1, actual_unit_cost_cents: 400)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_equal line.reload.open_quantity, 1
    assert_includes PurchaseOrder.sent.with_open_lines, po

    receipt_line = receipt.purchase_receipt_lines.first
    Purchasing::ReversePurchaseReceiptLine.call(
      purchase_receipt_line: receipt_line,
      actor: @actor,
      reason: "test reversal",
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_equal 2, line.reload.open_quantity
    assert_includes PurchaseOrder.sent.with_open_lines, po
  end

  test "with_open_lines excludes fully received sent PO" do
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1,
      supplier: @supplier
    )
    po = order.purchase_order
    line = po.purchase_order_lines.first
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )

    receipt = draft_receipt_with_line(line, received_quantity: 1, actual_unit_cost_cents: 400)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    Purchasing::ClosePurchaseOrderIfComplete.call!(
      purchase_order: po.reload,
      actor: @actor
    )

    assert_equal 0, line.reload.open_quantity
    assert_not_includes PurchaseOrder.sent.with_open_lines, po
  end

  private

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
