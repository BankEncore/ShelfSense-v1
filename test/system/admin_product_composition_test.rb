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

  test "show new and edit remain usable at 320 and zoom" do
    visit admin_products_path
    assert_selector ".page-header__eyebrow", text: /merchandise/i
    assert_selector "section.product-filters"
    assert_selector "td.cell-primary", text: "Composition Book"

    visit admin_product_path(@product)
    assert_selector ".page-header__eyebrow", text: /product/i
    assert_selector ".admin-page"
    assert_selector ".product-identity-strip", text: "ShelfSense ID"
    assert_selector ".product-catalog", text: "Catalog details"
    assert_selector ".product-catalog", text: "$18.99"
    assert_no_selector ".metric-strip"
    assert_no_selector ".product-rail"
    assert_selector ".product-cover", visible: :all, count: 0

    visit new_admin_product_path
    assert_selector ".page-header__title", text: "New product"
    assert_selector "form.product-form"
    assert_button "Create Product"

    visit edit_admin_product_path(@product)
    assert_selector ".page-header__title", text: "Edit product"
    assert_button "Save Product"

    with_viewport(width: 320, height: 568) do
      visit admin_product_path(@product)
      assert_selector ".page-header__title", text: "Composition Book"
      assert_selector ".product-catalog", text: "$18.99"
      assert_layout_usable(surface: "products-show-320")

      visit new_admin_product_path
      assert_selector ".page-header__title", text: "New product"
      assert_button "Create Product"
      assert_layout_usable(surface: "products-new-320")

      visit edit_admin_product_path(@product)
      assert_selector ".page-header__title", text: "Edit product"
      assert_button "Save Product"
      assert_layout_usable(surface: "products-edit-320")
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      visit admin_product_path(@product)
      assert_selector ".product-catalog", text: "Catalog details"
      assert_layout_usable(surface: "products-show-200-percent")

      visit new_admin_product_path
      assert_selector ".page-header__title", text: "New product"
      assert_layout_usable(surface: "products-new-200-percent")

      visit edit_admin_product_path(@product)
      assert_selector ".page-header__title", text: "Edit product"
      assert_layout_usable(surface: "products-edit-200-percent")
    end
  end

  test "wide product show exceeds standard users and stays within 90rem" do
    with_viewport(width: 1920, height: 1080) do
      visit admin_users_path
      assert_selector "h1", text: "Users"
      unmigrated_width = app_content_used_width
      root_px = page.evaluate_script("parseFloat(getComputedStyle(document.documentElement).fontSize)")
      max_wide = (90 * root_px) + 1
      max_standard = (72 * root_px) + 1

      visit admin_customers_path
      assert_selector ".page-header__title", text: "Customers"
      customers_width = app_content_used_width

      visit admin_adjustment_reasons_path
      assert_selector ".page-header__title", text: "Adjustment reasons"
      reasons_width = app_content_used_width

      visit admin_product_path(@product)
      assert_selector ".page-header__title", text: "Composition Book"
      product_width = app_content_used_width

      assert_in_delta unmigrated_width, customers_width, 1.0
      assert_in_delta unmigrated_width, reasons_width, 1.0
      assert_operator customers_width, :<=, max_standard
      assert_operator product_width, :>, unmigrated_width
      assert_operator product_width, :<=, max_wide
    end
  end

  private

  def app_content_used_width
    page.evaluate_script(<<~JS)
      document.querySelector("main.app-content").getBoundingClientRect().width
    JS
  end
end
