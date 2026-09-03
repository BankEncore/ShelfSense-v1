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

  test "new standard form materializes category class defaults" do
    list_klass = merchandise_class(
      code: "pva_list",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      inventory_mode: "inventory",
      target_margin_bps: 4000,
      default_supplier_returnable: true
    )
    category = merchandise_category(name: "PVA List Cat", default_standard_merchandise_class: list_klass)
    product = Products::Create.call(
      attributes: { name: "Materialize Std", status: "active", merchandise_category: category, list_price_cents: 2499 },
      actor: @actor
    )

    get new_admin_product_product_variant_path(product)
    assert_response :success
    assert_select "select#product_variant_merchandise_class_id option[selected][value=?]", list_klass.id
    assert_select "select#product_variant_inventory_mode option[selected][value=inventory]"
    assert_select "select#product_variant_pricing_method option[selected][value=list_price]"
    assert_select "input#product_variant_target_margin_bps[value=?]", "4000"
    assert_select "select#product_variant_supplier_returnable option[selected][value=?]", "true"
    assert_select "select#product_variant_tax_class_override_id option[value='']", text: /Inherit —/
    assert_select "select#product_variant_status option[selected]", text: "Active"
    assert_select "input#product_variant_regular_price[value=?]", "24.99"
    assert_select ".product-variant-context", text: /Class:/, count: 0
    assert_select "select#product_variant_merchandise_class_id option", text: /Resolve default/, count: 0
    assert_select "select#product_variant_inventory_mode option", text: /Use class default/, count: 0
  end

  test "new used form materializes used class and refreshes price on condition" do
    used_klass = merchandise_class(
      code: "pva_used",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      used_merchandise_allowed: true,
      inventory_mode: "inventory",
      target_margin_bps: 2500
    )
    category = merchandise_category(
      name: "PVA Used Cat",
      default_standard_merchandise_class: @klass,
      default_used_merchandise_class: used_klass
    )
    condition = merchandise_condition(code: "pva_good", name: "Good", price_adjustment_bps: 5000)
    product = Products::Create.call(
      attributes: { name: "Materialize Used", status: "active", merchandise_category: category, list_price_cents: 2000 },
      actor: @actor
    )

    get new_admin_product_product_variant_path(product), params: {
      product_variant: { variant_type: "used", status: "active", regular_price: "20.00" },
      refresh_fields: "1",
      refresh_source: "variant_type"
    }
    assert_response :success
    assert_select "select#product_variant_variant_type option[selected][value=used]"
    assert_select "select#product_variant_merchandise_class_id option[selected][value=?]", used_klass.id
    assert_select "select#product_variant_merchandise_condition_id", count: 1
    assert_select "select#product_variant_inventory_mode option[selected][value=inventory]"
    assert_select "input#product_variant_target_margin_bps[value=?]", "2500"
    assert_select "input#product_variant_regular_price[value]", count: 0
    assert_select "input#product_variant_regular_price:not([value])", count: 1

    get new_admin_product_product_variant_path(product), params: {
      product_variant: {
        variant_type: "used",
        status: "active",
        merchandise_class_id: used_klass.id,
        inventory_mode: "inventory",
        pricing_method: "list_price",
        target_margin_bps: 2500,
        supplier_returnable: true,
        merchandise_condition_id: condition.id,
        regular_price: "20.00"
      },
      refresh_fields: "1",
      refresh_source: "condition"
    }
    assert_response :success
    assert_select "input#product_variant_regular_price[value=?]", "10.00"
  end

  test "changing merchandise class on refresh reapplies that class defaults" do
    other = merchandise_class(
      code: "pva_other",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "cost_based",
      inventory_mode: "non_inventory",
      target_margin_bps: 1500,
      default_supplier_returnable: false
    )
    product = Products::Create.call(
      attributes: { name: "Class Change", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )

    get new_admin_product_product_variant_path(product), params: {
      product_variant: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: other.id,
        regular_price: "10.00"
      },
      refresh_fields: "1",
      refresh_source: "merchandise_class"
    }
    assert_response :success
    assert_select "select#product_variant_merchandise_class_id option[selected][value=?]", other.id
    assert_select "select#product_variant_inventory_mode option[selected][value=non_inventory]"
    assert_select "select#product_variant_pricing_method option[selected][value=cost_based]"
    assert_select "input#product_variant_target_margin_bps[value=?]", "1500"
    assert_select "select#product_variant_supplier_returnable option[selected][value=?]", "false"
    assert_select "input#product_variant_regular_price[value]", count: 0
    assert_select "input#product_variant_regular_price:not([value])", count: 1
  end

  test "product without category default requires class selection" do
    product = Products::Create.call(
      attributes: { name: "No Cat", status: "active", list_price_cents: 1000 },
      actor: @actor
    )
    get new_admin_product_product_variant_path(product)
    assert_response :success
    assert_select "select#product_variant_merchandise_class_id option[selected]", count: 0
    assert_select "select#product_variant_merchandise_class_id option[value='']", text: /Select merchandise class/
    assert_select "select#product_variant_inventory_mode option[selected]", count: 0
    assert_select "select#product_variant_tax_class_override_id option[value='']", text: /Select tax class/
    assert_select "select#product_variant_tax_class_override_id option[value='']", text: /Inherit —/, count: 0
  end

  test "create persists materialized form values" do
    list_klass = merchandise_class(
      code: "pva_persist",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      target_margin_bps: 4000
    )
    category = merchandise_category(name: "PVA Persist", default_standard_merchandise_class: list_klass)
    product = Products::Create.call(
      attributes: { name: "Persist Defaults", status: "active", merchandise_category: category, list_price_cents: 1999 },
      actor: @actor
    )

    assert_difference -> { ProductVariant.count }, 1 do
      post admin_product_product_variants_path(product), params: {
        product_variant: {
          variant_type: "standard",
          status: "active",
          merchandise_class_id: list_klass.id,
          inventory_mode: "inventory",
          pricing_method: "list_price",
          target_margin_bps: 4000,
          supplier_returnable: true,
          regular_price: "19.99"
        }
      }
    end
    variant = ProductVariant.order(:created_at).last
    assert_equal list_klass.id, variant.merchandise_class_id
    assert_equal "inventory", variant.inventory_mode
    assert_equal "list_price", variant.pricing_method
    assert_equal 4000, variant.target_margin_bps
    assert_equal true, variant.supplier_returnable
    assert_equal 1999, variant.regular_price_cents
    assert_nil variant.tax_class_override_id
  end

  test "edit form shows stored sticky values without reapplying class defaults" do
    list_klass = merchandise_class(
      code: "pva_edit_cls",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      target_margin_bps: 4000,
      default_supplier_returnable: true
    )
    product = Products::Create.call(
      attributes: { name: "Edit Sticky", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    variant = ProductVariants::Create.call(
      product: product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class: list_klass,
        inventory_mode: "inventory",
        pricing_method: "fixed",
        target_margin_bps: 1111,
        supplier_returnable: false,
        regular_price_cents: 555
      },
      actor: @actor
    )
    # Change class defaults after create — edit must not pick these up
    list_klass.update!(target_margin_bps: 9999, default_pricing_method: "cost_based")

    get edit_admin_product_variant_path(variant)
    assert_response :success
    assert_select "select#product_variant_pricing_method option[selected][value=fixed]"
    assert_select "input#product_variant_target_margin_bps[value=?]", "1111"
    assert_select "select#product_variant_supplier_returnable option[selected][value=?]", "false"
    assert_select "input#product_variant_regular_price[value=?]", "5.55"
  end

  test "validation failure keeps raw regular price text" do
    product = Products::Create.call(
      attributes: { name: "Raw Price", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    post admin_product_product_variants_path(product), params: {
      product_variant: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @klass.id,
        inventory_mode: "inventory",
        pricing_method: "fixed",
        supplier_returnable: true,
        regular_price: "abc"
      }
    }
    assert_response :unprocessable_entity
    assert_select "input#product_variant_regular_price[value=?]", "abc"
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
