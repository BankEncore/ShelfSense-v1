# frozen_string_literal: true

require "test_helper"

class Purchasing::ReceiptCorrectionsTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "corr_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Correctable Book")
    @supplier = Supplier.create!(name: "Ingram Correct", code: "igc_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    @customer = Customer.create!(display_name: "Casey Correct", email: "casey@example.com")
  end

  test "eligible reverse restores qty value and releases allocation" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Reverse Special")
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
    po = request.orders.first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    po_line = po.purchase_order_lines.first
    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 900)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    allocation = request.reload.active_allocation
    assert allocation.present?
    assert_equal "available", request.status
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: oos).on_hand_quantity

    Purchasing::ReversePurchaseReceiptLine.call(
      purchase_receipt_line: line,
      actor: @actor,
      reason: "wrong title received",
      idempotency_key: SecureRandom.uuid_v7
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: oos)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
    assert_nil request.reload.active_allocation
    assert_equal "released", allocation.reload.status
    assert_equal "ordered", request.status
    assert_equal 1, po_line.reload.open_quantity
    assert OutboxMessage.exists?(event_type: "inventory.receipt_reversed")
  end

  test "reverse blocked after pickup fulfilled" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Fulfilled Special")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 800,
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
    po_line = po.purchase_order_lines.first
    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 800)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    allocation = request.reload.active_allocation
    assert allocation.present?

    # Simulate completed pickup without full POS stack (status is what reverse checks).
    allocation.update_columns(
      status: "fulfilled",
      fulfilled_pos_transaction_line_id: nil,
      updated_at: Time.current
    )
    request.update_columns(
      status: "completed",
      completed_at: Time.current,
      updated_at: Time.current
    )
    InventoryBalance.find_by!(store: @store, product_variant: oos).update!(
      on_hand_quantity: 0,
      inventory_value_cents: 0
    )

    error = assert_raises(Purchasing::Error) do
      Purchasing::ReversePurchaseReceiptLine.call(
        purchase_receipt_line: line,
        actor: @actor,
        reason: "too late",
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/fulfilled|pickup|compensate/i, error.message)
    assert_equal 0, line.corrections.quantity_reversals.count
  end

  test "cost correction changes value not quantity" do
    seed_balance!(on_hand: 0, value_cents: 0)
    po_line = sent_stock_line(quantity: 2)
    receipt = draft_receipt_with_line(po_line, received_quantity: 2, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    balance_before = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance_before.on_hand_quantity
    assert_equal 1_000, balance_before.inventory_value_cents

    Purchasing::CorrectPurchaseReceiptLineCost.call(
      purchase_receipt_line: line,
      actor: @actor,
      reason: "invoice was 450",
      corrected_unit_cost_cents: 450,
      idempotency_key: SecureRandom.uuid_v7
    )

    balance = balance_before.reload
    assert_equal 2, balance.on_hand_quantity
    assert_equal 900, balance.inventory_value_cents
    assert_equal 500, line.reload.actual_unit_cost_cents
    correction = line.corrections.cost_corrections.last
    assert_equal(-100, correction.value_delta_cents)
    assert OutboxMessage.exists?(event_type: "inventory.receipt_cost_corrected")
  end

  test "whole receipt reverse is atomic" do
    seed_balance!(on_hand: 0, value_cents: 0)
    first = sent_stock_line(quantity: 1)
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
    second = second_po.purchase_order_lines.first

    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: first,
      actor: @actor,
      received_quantity: 1,
      actual_unit_cost_cents: 500
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: second,
      actor: @actor,
      received_quantity: 1,
      actual_unit_cost_cents: 500
    )
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt.reload,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    assert_equal 2, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity

    reversed = Purchasing::ReversePurchaseReceipt.call(
      purchase_receipt: receipt.reload,
      actor: @actor,
      reason: "entire shipment wrong",
      idempotency_key: SecureRandom.uuid_v7
    )

    assert_equal "reversed", reversed.status
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents
    assert_equal 2, PurchaseReceiptLineCorrection.quantity_reversals.where(
      purchase_receipt_line_id: receipt.purchase_receipt_lines.select(:id)
    ).count
    assert_equal 1, first.reload.open_quantity
    assert_equal 1, second.reload.open_quantity
  end

  test "unsafe reverse without compensate raises directing message" do
    seed_balance!(on_hand: 0, value_cents: 0)
    po_line = sent_stock_line(quantity: 1)
    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    InventoryBalance.find_by!(store: @store, product_variant: @variant).update!(
      on_hand_quantity: 0,
      inventory_value_cents: 0
    )

    error = assert_raises(Purchasing::Error) do
      Purchasing::ReversePurchaseReceiptLine.call(
        purchase_receipt_line: line,
        actor: @actor,
        reason: "already sold",
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/compensate/i, error.message)
  end

  test "authorized compensate after sale consumes reversible quantity without depleting" do
    seed_balance!(on_hand: 0, value_cents: 0)
    po_line = sent_stock_line(quantity: 1)
    receipt = draft_receipt_with_line(po_line, received_quantity: 1, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    InventoryBalance.find_by!(store: @store, product_variant: @variant).update!(
      on_hand_quantity: 0,
      inventory_value_cents: 0
    )

    correction = Purchasing::ReversePurchaseReceiptLine.call(
      purchase_receipt_line: line,
      actor: @actor,
      reason: "sold before reverse",
      authorize_compensate: true,
      idempotency_key: SecureRandom.uuid_v7
    )

    assert correction.compensating_adjustment_reference?
    assert_equal 1, correction.quantity
    assert_equal(-500, correction.value_delta_cents)
    assert_equal 0, line.reload.remaining_reversible_quantity
    assert_equal 1, po_line.reload.open_quantity
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 0, balance.on_hand_quantity
    assert_equal 0, balance.inventory_value_cents

    error = assert_raises(Purchasing::Error) do
      Purchasing::ReversePurchaseReceiptLine.call(
        purchase_receipt_line: line,
        actor: @actor,
        reason: "again",
        authorize_compensate: true,
        idempotency_key: SecureRandom.uuid_v7
      )
    end
    assert_match(/nothing left|exceeds remaining|only posted|fully reversed/i, error.message)
  end

  test "sequential cost corrections use effective cost not original posted cost" do
    seed_balance!(on_hand: 0, value_cents: 0)
    po_line = sent_stock_line(quantity: 2)
    receipt = draft_receipt_with_line(po_line, received_quantity: 2, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first

    Purchasing::CorrectPurchaseReceiptLineCost.call(
      purchase_receipt_line: line,
      actor: @actor,
      reason: "invoice 600",
      corrected_unit_cost_cents: 600,
      idempotency_key: SecureRandom.uuid_v7
    )
    Purchasing::CorrectPurchaseReceiptLineCost.call(
      purchase_receipt_line: line.reload,
      actor: @actor,
      reason: "invoice 550",
      corrected_unit_cost_cents: 550,
      idempotency_key: SecureRandom.uuid_v7
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, balance.on_hand_quantity
    assert_equal 1_100, balance.inventory_value_cents
    assert_equal 1_100, line.reload.effective_merchandise_value_cents
    assert_equal 550, line.effective_unit_cost_cents
  end

  test "partial reverse after cost correction removes effective value for reversed units" do
    seed_balance!(on_hand: 0, value_cents: 0)
    po_line = sent_stock_line(quantity: 2)
    receipt = draft_receipt_with_line(po_line, received_quantity: 2, actual_unit_cost_cents: 500)
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    Purchasing::CorrectPurchaseReceiptLineCost.call(
      purchase_receipt_line: line,
      actor: @actor,
      reason: "invoice 600",
      corrected_unit_cost_cents: 600,
      idempotency_key: SecureRandom.uuid_v7
    )

    Purchasing::ReversePurchaseReceiptLine.call(
      purchase_receipt_line: line.reload,
      actor: @actor,
      reason: "return one",
      quantity: 1,
      idempotency_key: SecureRandom.uuid_v7
    )

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 1, balance.on_hand_quantity
    assert_equal 600, balance.inventory_value_cents
    assert_equal 1, line.reload.remaining_reversible_quantity
    assert_equal 600, line.effective_merchandise_value_cents
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
    sent.purchase_order_lines.first
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
