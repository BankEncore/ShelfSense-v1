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
    assert_select ".product-summary", count: 0
  end

  test "show uses identity header metric strip and separate panels" do
    sign_in_as("admin")
    get admin_product_path(@product)
    assert_response :success

    assert_select ".product-identity .page-header__eyebrow", text: "Product"
    assert_select ".product-identity .page-header__title", text: "Example Book"
    assert_select ".product-identity .page-header__metadata", text: /#{Regexp.escape(@product.primary_identifier)}/
    assert_select ".product-identity .page-header__status", text: /Draft/
    assert_select ".metric-strip[aria-label='Product summary']"
    assert_select ".metric-strip__label", text: "List price"
    assert_select ".metric-strip__value", text: "$19.99"
    assert_select ".metric-strip__label", text: "Cover"
    assert_select ".metric-strip__value", text: "Missing"
    assert_select "img.product-cover", count: 0
    assert_select ".product-panels h2", text: "Identity"
    assert_select "h2", text: "Publication", count: 0
    assert_select ".product-summary", count: 0
    assert_select ".product-variants"
    assert_select ".product-variants td.cell-primary", text: @variant.name
    assert_select ".product-variants td.cell-identifier", text: @variant.sku
    assert_select ".product-variants td.cell-operational", minimum: 1
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
