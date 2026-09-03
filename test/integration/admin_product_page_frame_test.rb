# frozen_string_literal: true

require "test_helper"

class AdminProductPageFrameTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @product = Products::Create.call(
      attributes: { name: "Frame Product", status: "draft", list_price_cents: 1299 },
      actor: @bootstrap[:administrator]
    )
  end

  test "show uses the page frame at wide width without a rail" do
    sign_in_as("admin")
    get admin_product_path(@product)
    assert_response :success
    assert_page_frame modifier: "wide"
    assert_select ".admin-page__tools", count: 0
    assert_select ".metric-strip", count: 0
    assert_select ".product-rail", count: 0
    assert_select ".product-overview .product-identifiers dt", text: "ShelfSense ID"
    assert_select ".product-overview .product-facts dt", text: "List price"
    assert_select "h2", text: "Catalog details", count: 0
    assert_select ".page-header__actions", text: /Order stock/, count: 0
    assert_select ".page-header__actions", text: /Create customer request/, count: 0
  end

  test "new uses the page frame at wide width and keeps form sections" do
    sign_in_as("admin")
    get new_admin_product_path
    assert_response :success
    assert_page_frame modifier: "wide"
    assert_select "a", text: "Look up a book first"
    assert_select "form.product-form.surface"
    %w[Identity Variant\ attributes Identifiers Publication Cover Classification Pricing Lifecycle].each do |title|
      assert_select ".product-form h2", text: title
    end
    assert_select ".admin-form-footer", text: /Create Product/
    assert_select ".product-rail", count: 0
    assert_select ".product-overview", count: 0
    assert_select ".product-identity-strip", count: 0
    assert_select ".metric-strip", count: 0
  end

  test "edit uses the page frame at wide width" do
    sign_in_as("admin")
    get edit_admin_product_path(@product)
    assert_response :success
    assert_page_frame modifier: "wide"
    assert_select ".page-header__metadata", text: /#{Regexp.escape(@product.primary_identifier)}/
    assert_select "form.product-form.surface"
    assert_select ".admin-form-footer", text: /Save Product/
    assert_select ".product-rail", count: 0
    assert_select ".product-overview", count: 0
    assert_select ".product-identity-strip", count: 0
  end

  test "failed create redisplays wide with retained values" do
    sign_in_as("admin")
    post admin_products_path, params: {
      product: { name: "", status: "draft", list_price: "12.50" }
    }
    assert_response :unprocessable_entity
    assert_page_frame modifier: "wide"
    assert_select "input[name='product[list_price]'][value='12.50']"
    assert_select "form.product-form.surface"
  end

  test "sent purchase order open quantity appears as on-order" do
    tax = tax_class(code: "oo_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: @bootstrap[:administrator], tax_class: tax, name: "On Order Book")
    seed_sent_purchase_order(variant: variant, quantity: 13)

    sign_in_as("admin")
    get admin_product_path(variant.product)
    assert_response :success
    assert_page_frame modifier: "wide"
    assert_select ".product-variants th", text: "On order"
    assert_select ".product-variants th", text: "Available"
    assert_select ".product-variants th", text: "On hand"
    assert_select ".product-variants td", text: "13"
    assert_select ".product-variants", text: /Order stock/
    assert_select ".page-header__actions", text: /Order stock/, count: 0
    assert_select ".product-rail", count: 0
  end

  test "draft purchase order open quantity is not on-order" do
    tax = tax_class(code: "od_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: @bootstrap[:administrator], tax_class: tax, name: "Draft Order Book")
    seed_draft_purchase_order(variant: variant, quantity: 11)

    sign_in_as("admin")
    get admin_product_path(variant.product)
    assert_response :success
    assert_select ".product-variants th", text: "On order"
    assert_select ".product-variants td", text: "11", count: 0
  end

  test "unmigrated customers and users keep their width contracts" do
    sign_in_as("admin")
    get admin_users_path
    assert_response :success
    assert_select "main[class='app-content']"
    assert_select ".admin-page", count: 0

    customer = Customer.create!(display_name: "Width Check", email: "width@example.com", phone: "555-010-0090")
    get admin_customer_path(customer)
    assert_response :success
    assert_select "main[class='app-content app-content--standard']"
    assert_select "main.app-content.app-content--wide", count: 0
  end

  test "product scoped CSS does not change width tokens" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_match(/\.admin-page \.product-form\.form/, css)
    assert_match(/--content-max:\s*72rem/, css[/:root\s*\{[^}]+\}/m])
    assert_match(/--admin-content-wide:\s*90rem/, css[/:root\s*\{[^}]+\}/m])
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def assert_page_frame(modifier:)
    assert_select ".admin-page", count: 1
    assert_select "main.app-content .admin-page", count: 1
    assert_select ".admin-page .admin-page", count: 0
    assert_select "h1", count: 1
    assert_select "main[class='app-content app-content--#{modifier}']"
  end

  def seed_draft_purchase_order(variant:, quantity:)
    supplier = Supplier.create!(name: "Draft Supplier", code: "ds_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 750,
      organization_preferred: true
    )
    Purchasing::CreateStockOrder.call(
      store: @bootstrap[:store],
      product_variant: variant,
      actor: @bootstrap[:administrator],
      quantity: quantity,
      supplier: supplier
    ).purchase_order
  end

  def seed_sent_purchase_order(variant:, quantity:)
    po = seed_draft_purchase_order(variant: variant, quantity: quantity)
    actor = @bootstrap[:administrator]
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: actor,
      transmission_method: "email"
    )
  end
end
