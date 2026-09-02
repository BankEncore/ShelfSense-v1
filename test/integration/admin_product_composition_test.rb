# frozen_string_literal: true

require "test_helper"

class AdminProductCompositionTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @category = merchandise_category(name: "Fiction")
    @product = Products::Create.call(
      attributes: {
        name: "Example Book",
        status: "draft",
        merchandise_category: @category,
        list_price_cents: 1999
      },
      actor: @bootstrap[:administrator]
    )
    @variant = ProductVariants::Create.call(
      product: @product,
      actor: @bootstrap[:administrator],
      attributes: { variant_type: "standard", status: "draft" }
    )
  end

  test "index uses composed header filter grouping and table hierarchy" do
    sign_in_as("admin")
    get admin_products_path
    assert_response :success

    assert_select ".page-header__eyebrow", text: "Merchandise"
    assert_select ".page-header__title.type-page-title", text: "Products"
    assert_select "section.product-filters[aria-label='Product filters']"
    assert_select ".product-filters form.filters"
    assert_select "td.cell-primary a", text: "Example Book"
    assert_select "td.cell-identifier", text: @product.primary_identifier
    assert_select "td.cell-secondary", text: /Fiction/
    assert_select "th.cell-primary", count: 0
    assert_select "th.cell-identifier", count: 0
    assert_select "th.cell-secondary", count: 0
    assert_select ".product-summary", count: 0
    assert_select ".admin-page", count: 0
    assert_select "main[class='app-content']"
  end

  test "show uses the page frame identity catalog and full-width variants table" do
    sign_in_as("admin")
    get admin_product_path(@product)
    assert_response :success

    assert_select ".admin-page", count: 1
    assert_select "main.app-content.app-content--wide"
    assert_select ".page-header__eyebrow", text: "Product"
    assert_select ".page-header__title", text: "Example Book"
    assert_select ".page-header__status", text: /Draft/
    assert_select ".page-header__actions", text: /Order stock/, count: 0
    assert_select ".page-header__actions", text: /Create customer request/, count: 0
    assert_select ".metric-strip", count: 0
    assert_select ".product-rail", count: 0
    assert_select ".product-panels", count: 0
    assert_select "img.product-cover", count: 0
    assert_select ".product-identity-strip dt", text: "ShelfSense ID"
    assert_select ".product-identity-strip dd", text: @product.primary_identifier
    assert_select ".product-catalog h2", text: "Catalog details"
    assert_select ".product-catalog dt", text: "List price"
    assert_select ".product-catalog dd", text: "$19.99"
    assert_select ".product-catalog dt", text: "Merchandise category"
    assert_select ".product-variants"
    assert_select ".product-variants th", text: "Type"
    assert_select ".product-variants th", text: "SKU"
    assert_select ".product-variants th", text: "Name"
    assert_select ".product-variants th", text: "Class"
    assert_select ".product-variants th", text: "Price"
    assert_select ".product-variants th", text: "Status"
    assert_select ".product-variants td.cell-primary", text: @variant.name
    assert_select ".product-variants td.cell-identifier", text: @variant.sku
    assert_select ".product-variants td.cell-operational", minimum: 1
    assert_select ".product-variants th.cell-operational", count: 0
    assert_select ".product-variants th.cell-primary", count: 0
    assert_select ".product-summary", count: 0
  end

  test "application css packages serif and keeps receipt mono distinct" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    assert_match "Source Serif 4", css
    assert_match "--font-serif", css
    assert_match "--font-mono", css
    assert_match "--font-receipt", css
    assert_match "Inconsolata", css
    refute_match "fonts.googleapis.com", css
    refute_match "cdn.jsdelivr.net", css
    assert_match %r{--font-receipt:\s*"Inconsolata"}, css
    refute_match %r{--font-mono:[^;]*Inconsolata}, css
  end

  test "product family templates do not set font-family" do
    Dir[Rails.root.join("app/views/admin/products/**/*.html.erb")].each do |path|
      refute_match(/font-family/, File.read(path), "#{path} must not set font-family")
    end
    Dir[Rails.root.join("app/views/admin/product_catalog_searches/**/*.html.erb")].each do |path|
      refute_match(/font-family/, File.read(path), "#{path} must not set font-family")
    end
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
