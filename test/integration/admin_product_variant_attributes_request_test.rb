# frozen_string_literal: true

require "test_helper"

class AdminProductVariantAttributesRequestTest < ActionDispatch::IntegrationTest
  include Phase2Fixtures

  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    sign_in_as("admin")
    @tax = tax_class(code: "pva_req_tax")
    @dept = department(code: "pva_req_dept")
    @klass = merchandise_class(code: "pva_req_std", department: @dept, default_tax_class: @tax, pricing_method: "fixed")
    @category = merchandise_category(name: "PVA Req", default_standard_merchandise_class: @klass)
  end

  test "attributed product create redirects to first variant form" do
    assert_difference -> { Product.count }, 1 do
      post admin_products_path, params: {
        product: {
          name: "Logo Tee",
          status: "active",
          variant_option_name_1: "Size",
          merchandise_category_id: @category.id,
          list_price: "20.00"
        }
      }
    end
    product = Product.order(:created_at).last
    assert_redirected_to new_admin_product_product_variant_path(product)
    follow_redirect!
    assert_response :success
    assert_select ".product-variant-context", text: /Logo Tee/
    assert_select "label", text: "Size"
    assert_select "select#product_variant_status option[selected]", text: "Active"
  end

  test "variant type round-trip clears condition for Standard" do
    product = Products::Create.call(
      attributes: { name: "Round Trip", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    condition = merchandise_condition(code: "pva_rt")

    get new_admin_product_product_variant_path(product), params: {
      product_variant: {
        variant_type: "standard",
        merchandise_condition_id: condition.id,
        option_value_1: "ignored",
        status: "active"
      },
      refresh_fields: "1"
    }
    assert_response :success
    assert_select "select#product_variant_merchandise_condition_id", count: 0
    assert_select "select#product_variant_variant_type option[selected][value=standard]"
  end

  test "new variant form shows derived name preview element" do
    product = Products::Create.call(
      attributes: { name: "Preview Product", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    get new_admin_product_product_variant_path(product)
    assert_response :success
    assert_select "[data-variant-preview-target='preview']", count: 1
    assert_select "[data-controller='variant-preview']", count: 1
  end

  test "edit variant form shows derived name preview element" do
    product = Products::Create.call(
      attributes: { name: "Preview Edit", status: "active", variant_option_name_1: "Size", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    variant = ProductVariants::Create.call(
      product: product,
      attributes: { variant_type: "standard", option_value_1: "M", status: "active",
                    merchandise_class: @klass, inventory_mode: "inventory", pricing_method: "fixed",
                    supplier_returnable: true, regular_price_cents: 1500 },
      actor: @actor
    )
    get edit_admin_product_variant_path(variant)
    assert_response :success
    assert_select "[data-variant-preview-target='preview']", count: 1
    assert_select "[data-controller='variant-preview']", count: 1
  end

  test "no-JS server fallback: form saves correctly without Stimulus" do
    product = Products::Create.call(
      attributes: { name: "NoJS Save", status: "active", variant_option_name_1: "Color", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    assert_difference -> { ProductVariant.count }, 1 do
      post admin_product_product_variants_path(product), params: {
        product_variant: {
          variant_type: "standard",
          option_value_1: "Red",
          status: "active",
          merchandise_class_id: @klass.id,
          inventory_mode: "inventory",
          pricing_method: "fixed",
          supplier_returnable: true,
          regular_price: "10.00"
        }
      }
    end
    variant = ProductVariant.order(:created_at).last
    assert_equal "Red", variant.name
    assert_redirected_to admin_product_variant_path(variant)
  end

  test "tax inherit blank option appears when class has default tax" do
    product = Products::Create.call(
      attributes: { name: "Inherit Tax", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    get new_admin_product_product_variant_path(product)
    assert_response :success
    assert_select "select#product_variant_tax_class_override_id option[value='']", text: /Inherit —/
    assert_select "select#product_variant_inventory_mode option", text: /Inherit/, count: 0
  end

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
