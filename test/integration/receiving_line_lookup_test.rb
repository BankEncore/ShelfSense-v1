# frozen_string_literal: true

require "test_helper"

class ReceivingLineLookupTest < ActionDispatch::IntegrationTest
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    @tax = tax_class(code: "rlu_#{SecureRandom.hex(2)}")
    @supplier = Supplier.create!(name: "Lookup Supplier", code: "rlu_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Scannable Receiving Book")
    SupplierVariantSource.create!(supplier: @supplier, product_variant: @variant,
      pricing_method: "direct_unit_cost", expected_unit_cost_cents: 725, organization_preferred: true)
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }
  end

  test "single, ambiguous, repeated, no-match, and customer-request lookups are scoped and serialized" do
    first = sent_order(@variant, quantity: 3)
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(store: @store, supplier: @supplier, actor: @actor)

    get ops_receiving_line_lookup_path(receipt), params: { query: @variant.sku }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "selected", body["outcome"]
    assert_equal 3, body.dig("matches", 0, "open_quantity")
    assert_equal "7.25", body.dig("matches", 0, "expected_unit_cost")
    assert_equal "$7.25", body.dig("matches", 0, "expected_unit_cost_formatted")

    Purchasing::AddPurchaseReceiptLine.call(purchase_receipt: receipt,
      purchase_order_line: first.purchase_order_line, actor: @actor,
      received_quantity: 4, actual_unit_cost_cents: 700)
    get ops_receiving_line_lookup_path(receipt), params: { query: @variant.sku }, as: :json
    assert_equal "selected", response.parsed_body["outcome"], "a repeated scan remains eligible while the PO is open"

    second = sent_order(@variant, quantity: 2)
    get ops_receiving_line_lookup_path(receipt), params: { query: @variant.sku }, as: :json
    body = response.parsed_body
    assert_equal "multiple", body["outcome"]
    assert_equal [ first.purchase_order.number, second.purchase_order.number ].sort, body["matches"].pluck("po_number").sort
    assert body["matches"].all? { |match| match.key?("order_date") && match.key?("product") }

    get ops_receiving_line_lookup_path(receipt), params: { query: "DOES-NOT-EXIST" }, as: :json
    assert_equal "no_match", response.parsed_body["outcome"]

    customer = Customer.create!(display_name: "Lookup Reader", email: "lookup-reader@example.com")
    customer_variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Customer Lookup Book")
    SupplierVariantSource.create!(supplier: @supplier, product_variant: customer_variant,
      pricing_method: "direct_unit_cost", expected_unit_cost_cents: 515, organization_preferred: true)
    request = Customers::CreateRequest.call(store: @store, customer: customer,
      product_variant: customer_variant, actor: @actor)
    po = request.orders.first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(purchase_order: po.reload, actor: @actor, transmission_method: "email")

    get ops_receiving_line_lookup_path(receipt), params: { query: request.number }, as: :json
    match = response.parsed_body.fetch("matches").first
    assert_equal request.number, match["customer_request"]
  end

  test "used identifier is reported as ineligible" do
    used = pos_sellable_variant(actor: @actor, tax_class: @tax, variant_type: "used", name: "Used Lookup Book")
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(store: @store, supplier: @supplier, actor: @actor)

    get ops_receiving_line_lookup_path(receipt), params: { query: used.sku }, as: :json

    assert_equal "ineligible", response.parsed_body["outcome"]
    assert_match(/Used variants/, response.parsed_body["message"])
  end

  private

  def sent_order(variant, quantity:)
    order = Purchasing::CreateStockOrder.call(store: @store, product_variant: variant,
      supplier: @supplier, actor: @actor, quantity: quantity)
    po = order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(purchase_order: po.reload, actor: @actor, transmission_method: "email")
    order
  end

  test "receiving show exposes scanner landmark for workflow layer" do
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(store: @store, supplier: @supplier, actor: @actor)
    get ops_receiving_path(receipt)
    assert_response :success
    assert_select "input[name='receiving_lookup']"
    assert_select "main"
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
