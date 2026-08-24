# frozen_string_literal: true

require "test_helper"

class PurchasingOpsMutationFailuresTest < ActionDispatch::IntegrationTest
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "ops_failure_#{SecureRandom.hex(3)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "Failure Retention Book")
    @supplier = Supplier.create!(name: "Failure Supplier", code: "fail_#{SecureRandom.hex(3)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 725,
      organization_preferred: true
    )
    @purchase_order = Purchasing::CreateStockOrder.call(
      store: @store, product_variant: @variant, actor: @actor, quantity: 1
    ).purchase_order
    post session_path, params: { session: { username: @actor.username, password: "correct-horse-battery" } }
  end

  test "draft PO stale row response retains strings, row selection, focus, and current values" do
    line = @purchase_order.purchase_order_lines.first
    order = line.order
    submitted_version = order.lock_version
    order.update!(notes: "current buyer note")

    patch ops_purchase_order_update_line_path(@purchase_order, line), params: {
      lock_version: submitted_version,
      quantity: "07",
      expected_unit_cost_cents: "00999",
      notes: "submitted buyer note"
    }

    assert_response :unprocessable_entity
    assert_select "[data-ops-error-summary]", text: /changed by someone else/i
    assert_select "tr.is-selected[aria-selected='true'] input[name='quantity'][value='07'][autofocus]"
    assert_select "tr.is-selected input[name='expected_unit_cost_cents'][value='00999']"
    assert_select "tr.is-selected input[name='notes'][value='submitted buyer note']"
    assert_select "tr.is-selected", text: /Current:.*current buyer note/
    assert_select "a", text: "Reload current values"
  end

  test "receipt validation retains quantity, cost, notes, selected row, and invalid-control focus" do
    Purchasing::GeneratePurchaseOrder.call(purchase_order: @purchase_order, actor: @actor)
    Purchasing::SendPurchaseOrder.call(purchase_order: @purchase_order.reload, actor: @actor, transmission_method: "email")
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(store: @store, supplier: @supplier, actor: @actor)
    po_line = @purchase_order.purchase_order_lines.first

    post ops_receiving_add_line_path(receipt), params: {
      lock_version: receipt.lock_version,
      purchase_order_line_id: po_line.id,
      received_quantity: "0",
      actual_unit_cost_cents: "00888",
      notes: "keep receiving note"
    }

    assert_response :unprocessable_entity
    assert_select "[data-ops-error-summary]"
    assert_select "input[name='purchase_order_line_id'][value='#{po_line.id}']"
    assert_select "input[name='received_quantity'][value='0'][autofocus]"
    assert_select "input[name='actual_unit_cost_cents'][value='00888']"
    assert_select "input[name='notes'][value='keep receiving note']"
    assert_select ".ops-row-error"
  end

  test "location exception retains row notes, cost, supplier choice, and focus" do
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1, unit_cost_cents: 100)
    customer = Customer.create!(display_name: "Failure Customer", email: "failure@example.com")
    customer_request = Customers::CreateRequest.call(
      store: @store, customer: customer, product_variant: @variant, actor: @actor
    )

    post ops_location_not_located_path(customer_request), params: {
      lock_version: customer_request.lock_version,
      convert_to_special_order: "1",
      supplier_id: SecureRandom.uuid_v7,
      expected_unit_cost_cents: "1.23",
      notes: "retain location note"
    }

    assert_response :unprocessable_entity
    assert_select "tr.is-selected[aria-selected='true']"
    assert_select ".location-action-panel:not([hidden])[data-request-id='#{customer_request.id}']" do
      assert_select "input[name='notes'][value='retain location note']"
      assert_select "input[name='expected_unit_cost_cents'][value='1.23']"
      assert_select ".ops-row-error"
    end
  end
end
