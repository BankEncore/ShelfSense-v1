# frozen_string_literal: true

require "application_system_test_case"

class AdminProductSearchFormCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @product = Products::Create.call(
      attributes: { name: "Composition Book", status: "draft" },
      actor: @bootstrap[:administrator]
    )
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "catalog search and product form remain usable at 320 and zoom" do
    visit new_admin_product_catalog_search_path
    assert_selector ".page-header__eyebrow", text: /merchandise/i
    assert_selector "section.catalog-search-query"
    assert_field "ISBN or title"

    visit new_admin_product_path
    assert_selector ".form-section", text: "Identity"
    assert_selector ".admin-form-footer", text: "Create Product"

    visit edit_admin_product_path(@product)
    assert_selector ".form-section", text: "Identifiers"
    assert_selector ".admin-form-footer", text: "Save Product"

    with_viewport(width: 320, height: 568) do
      assert_selector ".admin-form-footer", text: "Save Product"
      assert_selector "#product_name"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector ".admin-form-footer", text: "Save Product"
    end
  end
end
