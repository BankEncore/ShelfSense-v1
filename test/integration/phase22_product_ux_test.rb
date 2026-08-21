# frozen_string_literal: true

require "test_helper"

class Phase22ProductUxTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @actor = @admin
    @category = merchandise_category(name: "Fiction")
    @product = Products::Create.call(
      attributes: {
        name: "Example Book",
        status: "draft",
        merchandise_category: @category,
        list_price_cents: 1999
      },
      actor: @actor
    )
  end

  test "product index search filter and currency form round trip" do
    sign_in_as("admin")

    get admin_products_path, params: { q: "Example", status: "draft", merchandise_category_id: @category.id }
    assert_response :success
    assert_match(/Example Book/, response.body)
    assert_match(/\$19\.99/, response.body)

    get edit_admin_product_path(@product)
    assert_response :success

    patch admin_product_path(@product), params: {
      product: {
        name: "Example Book",
        status: "draft",
        merchandise_category_id: @category.id,
        list_price: "25.50",
        lock_version: @product.lock_version
      }
    }
    assert_redirected_to admin_product_path(@product)
    assert_equal 2550, @product.reload.list_price_cents

    patch admin_product_path(@product), params: {
      product: {
        name: "Example Book",
        status: "draft",
        list_price: "nope",
        lock_version: @product.lock_version
      }
    }
    assert_response :unprocessable_entity
    assert_match(/not a valid amount|error/i, response.body)
    assert_equal 2550, @product.reload.list_price_cents
  end

  test "product form offers no identifier mode and records identity fields" do
    sign_in_as("admin")

    get new_admin_product_path
    assert_response :success
    assert_select "select#product_identifier_mode", count: 0
    assert_select "input#product_external_identifier", count: 0
    assert_select "input#product_industry_identifier"
    assert_select "input#product_lookup_code"

    post admin_products_path, params: {
      product: {
        name: "Identity Book",
        status: "draft",
        industry_identifier: "0-306-40615-2",
        lookup_code: "shelf-a1"
      }
    }
    assert_response :redirect
    created = Product.find_by!(name: "Identity Book")
    assert created.primary_identifier.start_with?("222")
    assert_equal "9780306406157", created.industry_identifier
    assert_equal "SHELF-A1", created.lookup_code
    assert_equal "product_industry",
                 IdentifierRegistry.find_by!(value: created.industry_identifier).identifier_kind
  end

  test "product detail warns that a shared lookup code will require product selection" do
    sign_in_as("admin")
    @product.update!(lookup_code: "SHARED")
    other = Products::Create.call(
      attributes: { name: "Other Book", status: "draft" },
      actor: @actor,
      lookup_code: "SHARED"
    )

    get admin_product_path(@product)
    assert_response :success
    assert_match(/SHARED/, response.body)
    assert_match(/shared with 1 other product/, response.body)

    get admin_product_path(other)
    assert_response :success
    assert_match(/shared with 1 other product/, response.body)
  end

  test "clearing the industry identifier retires its registry row" do
    sign_in_as("admin")
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: external_isbn13)
    @product.reload

    patch admin_product_path(@product), params: {
      product: {
        name: @product.name,
        status: "draft",
        industry_identifier: "",
        lock_version: @product.lock_version
      }
    }

    assert_redirected_to admin_product_path(@product)
    assert_nil @product.reload.industry_identifier
    assert IdentifierRegistry.find_by!(value: external_isbn13).retired_at.present?
  end

  test "variant regular price uses currency parsing" do
    sign_in_as("admin")
    tax = tax_class(code: "books")
    dept = department(code: "new_books")
    klass = merchandise_class(code: "book", pricing_method: "fixed", department: dept, default_tax_class: tax)

    post admin_product_product_variants_path(@product), params: {
      product_variant: {
        variant_type: "standard",
        merchandise_class_id: klass.id,
        regular_price: "14.00",
        status: "draft"
      }
    }
    assert_response :redirect
    variant = @product.product_variants.order(:created_at).last
    assert_equal 1400, variant.regular_price_cents
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
