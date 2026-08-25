# frozen_string_literal: true

require "application_system_test_case"

class AdminProductCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @product = Products::Create.call(
      attributes: { name: "Composition Book", status: "draft", list_price_cents: 1899 },
      actor: @bootstrap[:administrator]
    )
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "index and show composition remain usable at 320 and zoom" do
    visit admin_products_path
    assert_selector ".page-header__eyebrow", text: /merchandise/i
    assert_selector "section.product-filters"
    assert_selector "td.cell-primary", text: "Composition Book"

    visit admin_product_path(@product)
    assert_selector ".page-header__eyebrow", text: /product/i
    assert_selector ".metric-strip"
    assert_selector ".product-panels", text: "Identity"
    assert_selector ".product-cover", visible: :all, count: 0

    with_viewport(width: 320, height: 568) do
      assert_selector ".page-header__title", text: "Composition Book"
      assert_selector ".metric-strip__value", text: "$18.99"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector ".product-panels", text: "Identity"
    end
  end
end
