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
    assert_match(/Cancel \/ re-source/, response.body)
    assert_match(/Acknowledgment/, response.body)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
