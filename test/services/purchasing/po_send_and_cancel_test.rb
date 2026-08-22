# frozen_string_literal: true

require "test_helper"

class Purchasing::PoSendAndCancelTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "po_send_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Sendable Book")
    @supplier = Supplier.create!(name: "Ingram Send", code: "igs_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 750,
      organization_preferred: true
    )
    @customer = Customer.create!(display_name: "Pat Reader", email: "pat@example.com")
    @other_supplier = Supplier.create!(name: "Baker", code: "bak_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @other_supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 800
    )
  end

  test "generate assigns store-scoped PO number that is never reused" do
    po = create_draft_po(quantity: 2)

    generated = Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    assert_equal 1, generated.number
    assert generated.generated_at.present?
    assert_equal 0, generated.document_revision

    Purchasing::ReturnPurchaseOrderToDraft.call(purchase_order: generated, actor: @actor)
    regenerated = Purchasing::GeneratePurchaseOrder.call(purchase_order: generated.reload, actor: @actor)
    assert_equal 1, regenerated.number
    assert_equal 1, regenerated.document_revision

    other_order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1,
      supplier: @other_supplier
    )
    other_po = other_order.purchase_order
    other_generated = Purchasing::GeneratePurchaseOrder.call(purchase_order: other_po, actor: @actor)
    assert_equal 2, other_generated.number
  end

  test "send freezes snapshots and rejects draft edits" do
    po = create_draft_po(quantity: 3)
    line = po.purchase_order_lines.first
    order = line.order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)

    sent = Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    assert_equal "sent", sent.status
    assert sent.sent_at.present?
    assert_equal "email", sent.transmission_method
    assert line.reload.line_state.present?

    edit_error = assert_raises(Purchasing::Error) do
      Purchasing::UpdateDraftOrder.call(order: order, actor: @actor, quantity: 9)
    end
    assert_match(/unsent draft/i, edit_error.message)

    add_error = assert_raises(Purchasing::Error) do
      Purchasing::AddStockOrderToDraftPo.call(
        purchase_order: sent,
        product_variant: @variant,
        actor: @actor,
        quantity: 1
      )
    end
    assert_match(/draft/i, add_error.message)
  end

  test "send transitions special_order_pending request to ordered" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "OOS Send")
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
    assert_equal "special_order_pending", request.status
    po = request.orders.first.purchase_order

    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "phone"
    )

    assert_equal "ordered", request.reload.status
    assert OutboxMessage.exists?(event_type: "purchase_order.sent", aggregate_id: po.id)
  end

  test "return to draft only when allowed" do
    po = create_draft_po(quantity: 1)
    before_generate = assert_raises(Purchasing::Error) do
      Purchasing::ReturnPurchaseOrderToDraft.call(purchase_order: po, actor: @actor)
    end
    assert_match(/not been generated/i, before_generate.message)

    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    returned = Purchasing::ReturnPurchaseOrderToDraft.call(purchase_order: po.reload, actor: @actor)
    assert_nil returned.generated_at
    assert_equal 1, returned.number

    Purchasing::GeneratePurchaseOrder.call(purchase_order: returned.reload, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: returned.reload,
      actor: @actor,
      transmission_method: "fax"
    )
    after_send = assert_raises(Purchasing::Error) do
      Purchasing::ReturnPurchaseOrderToDraft.call(purchase_order: returned.reload, actor: @actor)
    end
    assert_match(/already sent|only draft/i, after_send.message)
  end

  test "cancel reduces open quantity and re-source creates replacement" do
    po = create_draft_po(quantity: 4)
    line = po.purchase_order_lines.first
    order = line.order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )

    assert_equal 4, line.reload.open_quantity

    result = Purchasing::CancelPurchaseOrderQuantity.call(
      purchase_order_line: line,
      actor: @actor,
      quantity: 2,
      source: "buyer",
      reason: "supplier short",
      re_source: true,
      replacement_supplier: @other_supplier
    )

    assert_equal 2, line.reload.open_quantity
    assert_equal 2, line.cancelled_quantity
    replacement = result[:replacement_order]
    assert replacement.present?
    assert_equal order.id, replacement.replaces_order_id
    assert_equal @other_supplier, replacement.supplier
    assert_equal 2, replacement.requested_quantity
    assert_equal "draft", replacement.purchase_order.status
    assert_nil replacement.customer_request_id
    assert_equal "sent", po.reload.status
  end

  test "cancel all open quantity auto-closes the PO" do
    po = create_draft_po(quantity: 2)
    line = po.purchase_order_lines.first
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "portal"
    )

    Purchasing::CancelPurchaseOrderQuantity.call(
      purchase_order_line: line,
      actor: @actor,
      quantity: 2,
      source: "supplier",
      reason: "discontinued"
    )

    po.reload
    assert_equal 0, line.reload.open_quantity
    assert_equal "closed", po.status
    assert po.closed_at.present?
    assert OutboxMessage.exists?(event_type: "purchase_order.closed", aggregate_id: po.id)
  end

  test "re-source preserves customer_request_id" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "OOS Resource")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400,
      organization_preferred: true
    )
    SupplierVariantSource.create!(
      supplier: @other_supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 450
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )
    order = request.orders.first
    po = order.purchase_order
    line = order.purchase_order_line

    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    assert_equal "ordered", request.reload.status

    result = Purchasing::CancelPurchaseOrderQuantity.call(
      purchase_order_line: line,
      actor: @actor,
      quantity: 1,
      source: "buyer",
      reason: "change supplier",
      re_source: true,
      replacement_supplier: @other_supplier
    )

    replacement = result[:replacement_order]
    assert_equal request.id, replacement.customer_request_id
    assert_equal "special_order_pending", request.reload.status
    assert_equal "closed", po.reload.status
  end

  test "generated PO rejects edits until returned to draft" do
    po = create_draft_po(quantity: 1)
    order = po.purchase_order_lines.first.order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)

    error = assert_raises(Purchasing::Error) do
      Purchasing::UpdateDraftOrder.call(order: order, actor: @actor, quantity: 5)
    end
    assert_match(/return to draft/i, error.message)
  end

  private

  def create_draft_po(quantity:)
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: quantity,
      supplier: @supplier
    )
    order.purchase_order
  end
end
