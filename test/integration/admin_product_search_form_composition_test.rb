# frozen_string_literal: true

require "test_helper"

class AdminProductSearchFormCompositionTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @product = Products::Create.call(
      attributes: { name: "Example Book", status: "draft", list_price_cents: 1999 },
      actor: @bootstrap[:administrator]
    )
  end

  test "catalog search uses composed header query grouping and candidate table hierarchy" do
    sign_in_as("admin")
    get new_admin_product_catalog_search_path
    assert_response :success

    assert_select ".page-header__eyebrow", text: "Merchandise"
    assert_select ".page-header__title", text: "Find a book"
    assert_select "section.catalog-search-query[aria-label='Catalog search']"
    assert_select ".catalog-search-query form[action=?]", admin_product_catalog_searches_path
    assert_select "input[name='catalog_search[q]']"
    assert_select "a", text: "Create blank product"

    stub_bibliographic_provider(FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])) do
      post admin_product_catalog_searches_path, params: { catalog_search: { q: FIXTURE_ISBN13 } }
      assert_response :success
    end

    assert_select ".catalog-search-results"
    assert_select "td.cell-primary", text: "The Left Hand of Darkness"
    assert_select "td.cell-identifier", text: FIXTURE_ISBN13
    assert_select "td.cell-secondary", text: /Ursula K. Le Guin/
    assert_select "th.cell-primary", count: 0
    assert_select "th.cell-identifier", count: 0
    assert_select "th.cell-secondary", count: 0
    assert_match(/Use this book/, response.body)
  end

  test "product form uses sectioned layout grids and sticky actions" do
    sign_in_as("admin")
    get new_admin_product_path
    assert_response :success

    assert_select ".page-header__eyebrow", text: "Product"
    assert_select "form.product-form.surface"
    %w[Identity Variant\ attributes Identifiers Publication Cover Classification Pricing Lifecycle].each do |title|
      assert_select ".product-form h2", text: title
    end
    assert_select ".product-form .form-section__grid"
    assert_select "input#product_industry_identifier"
    assert_select "input#product_lookup_code"
    assert_select "input#product_name"
    assert_select ".admin-form-footer", text: /Create Product/
    assert_select ".admin-form-footer a", text: "Cancel"

    get edit_admin_product_path(@product)
    assert_response :success
    assert_select ".page-header__metadata", text: /#{Regexp.escape(@product.primary_identifier)}/
    assert_select ".admin-form-footer", text: /Save Product/
    assert_select "code", text: @product.primary_identifier
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
