# frozen_string_literal: true

require "application_system_test_case"

class AdminVariantPreviewTest < ApplicationSystemTestCase
  include Phase2Fixtures

  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "avp_tax")
    @dept = department(code: "avp_dept")
    @klass = merchandise_class(code: "avp_std", department: @dept, default_tax_class: @tax, pricing_method: "fixed")
    @category = merchandise_category(name: "AVP Cat", default_standard_merchandise_class: @klass)
  end

  test "preview shows Standard for a new standard variant without attributes" do
    product = Products::Create.call(
      attributes: { name: "Plain Product", status: "active", merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    sign_in_admin(actor: @actor)
    visit new_admin_product_product_variant_path(product)

    assert_selector "[data-variant-preview-target='preview']", text: "Standard"
  end

  test "preview updates as option values are typed" do
    product = Products::Create.call(
      attributes: { name: "Tee", status: "active", variant_option_name_1: "Size", variant_option_name_2: "Color",
                    merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    sign_in_admin(actor: @actor)
    visit new_admin_product_product_variant_path(product)

    fill_in "Size", with: "Large"
    assert_selector "[data-variant-preview-target='preview']", text: "Large"

    fill_in "Color", with: "Red"
    assert_selector "[data-variant-preview-target='preview']", text: "Large / Red"
  end

  test "preview reflects condition name for used variant" do
    used_klass = merchandise_class(
      code: "avp_used", department: @dept, default_tax_class: @tax,
      pricing_method: "fixed", used_merchandise_allowed: true
    )
    category_with_used = merchandise_category(
      name: "AVP Used Cat",
      default_standard_merchandise_class: @klass,
      default_used_merchandise_class: used_klass
    )
    condition = merchandise_condition(code: "avp_good", name: "Good")
    product = Products::Create.call(
      attributes: { name: "Used Product", status: "active", merchandise_category: category_with_used, list_price_cents: 1000 },
      actor: @actor
    )
    sign_in_admin(actor: @actor)

    # Navigate to new variant form with variant_type=used via refresh
    visit new_admin_product_product_variant_path(product, product_variant: { variant_type: "used", status: "active" }, refresh_fields: "1")

    select condition.name, from: "Condition"
    assert_selector "[data-variant-preview-target='preview']", text: condition.name
  end

  test "preview updates on edit form when option values change" do
    product = Products::Create.call(
      attributes: { name: "Edit Tee", status: "active", variant_option_name_1: "Size",
                    merchandise_category: @category, list_price_cents: 1000 },
      actor: @actor
    )
    variant = ProductVariants::Create.call(
      product: product,
      attributes: { variant_type: "standard", option_value_1: "S", status: "active",
                    merchandise_class: @klass, inventory_mode: "inventory", pricing_method: "fixed",
                    supplier_returnable: true, regular_price_cents: 1500 },
      actor: @actor
    )
    sign_in_admin(actor: @actor)
    visit edit_admin_product_variant_path(variant)

    assert_selector "[data-variant-preview-target='preview']", text: "S"

    fill_in "Size", with: "Medium"
    assert_selector "[data-variant-preview-target='preview']", text: "Medium"
  end
end
