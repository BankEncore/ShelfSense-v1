# frozen_string_literal: true

require "test_helper"

class OrdersAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "oi_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Admin Order")
    @supplier = Supplier.create!(name: "Admin Supp", code: "as_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400,
      organization_preferred: true
    )
  end

  test "authorized user can create stock order and open draft PO workspace" do
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get new_admin_order_path
    assert_response :success

    assert_difference -> { Order.count }, 1 do
      post admin_orders_path, params: {
        order: {
          product_variant_id: @variant.id,
          requested_quantity: 2,
          notes: "frontlist"
        }
      }
    end
    order = Order.order(:created_at).last
    assert_redirected_to ops_purchase_order_path(order.purchase_order)

    get ops_draft_pos_path
    assert_response :success
    assert_match(/Draft purchase orders/, response.body)

    po = order.purchase_order
    get ops_purchase_order_path(po)
    assert_response :success
    assert_match(/Add stock line/, response.body)
  end

  test "product and variant pages expose order stock and request actions" do
    sign_in_as("admin")
    post store_selection_path, params: { store_id: @store.id }

    get admin_product_variant_path(@variant)
    assert_response :success
    assert_match(/Order stock/, response.body)
    assert_match(/Create customer request/, response.body)
    assert_includes response.body, new_admin_order_path(product_variant_id: @variant.id)
    assert_includes response.body, new_admin_customer_request_path(product_variant_id: @variant.id)

    get admin_product_path(@variant.product)
    assert_response :success
    assert_match(/Order stock/, response.body)

    get new_admin_order_path(product_variant_id: @variant.id)
    assert_response :success
    assert_match(@variant.sku, response.body)
    assert_select "input[type=hidden][name='order[product_variant_id]'][value=?]", @variant.id
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
