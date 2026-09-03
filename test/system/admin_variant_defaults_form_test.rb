# frozen_string_literal: true

require "application_system_test_case"

class AdminVariantDefaultsFormTest < ApplicationSystemTestCase
  include Phase2Fixtures

  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "avd_tax")
    @dept = department(code: "avd_dept")
  end

  test "browser refresh replaces stale regular price for used condition and persists it" do
    list_klass = merchandise_class(
      code: "avd_list",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      used_merchandise_allowed: true,
      inventory_mode: "inventory",
      target_margin_bps: 4000
    )
    used_klass = merchandise_class(
      code: "avd_used",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      used_merchandise_allowed: true,
      inventory_mode: "inventory",
      target_margin_bps: 2500
    )
    category = merchandise_category(
      name: "AVD Used Cat",
      default_standard_merchandise_class: list_klass,
      default_used_merchandise_class: used_klass
    )
    condition = merchandise_condition(code: "avd_good", name: "Good", price_adjustment_bps: 5000)
    product = Products::Create.call(
      attributes: { name: "Price Refresh Book", status: "active", merchandise_category: category, list_price_cents: 2000 },
      actor: @actor
    )

    sign_in_admin(actor: @actor)
    visit new_admin_product_product_variant_path(product)

    assert_field "Regular price", with: "20.00"

    select "Used", from: "Variant type"
    assert_selector "label", text: "Condition"
    assert_field "Regular price", with: ""

    select condition.name, from: "Condition"
    assert_field "Regular price", with: "10.00"

    click_on "Create Variant"
    assert_text "Product variant created."
    variant = ProductVariant.order(:created_at).last
    assert_equal "used", variant.variant_type
    assert_equal condition.id, variant.merchandise_condition_id
    assert_equal 1000, variant.regular_price_cents
  end

  test "browser merchandise class change clears previous list-price suggestion" do
    list_klass = merchandise_class(
      code: "avd_books",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "list_price",
      inventory_mode: "inventory"
    )
    fixed_klass = merchandise_class(
      code: "avd_fixed",
      department: @dept,
      default_tax_class: @tax,
      pricing_method: "fixed",
      inventory_mode: "inventory"
    )
    category = merchandise_category(name: "AVD Class Cat", default_standard_merchandise_class: list_klass)
    product = Products::Create.call(
      attributes: { name: "Class Price Book", status: "active", merchandise_category: category, list_price_cents: 2499 },
      actor: @actor
    )

    sign_in_admin(actor: @actor)
    visit new_admin_product_product_variant_path(product)

    assert_field "Regular price", with: "24.99"
    select fixed_klass.admin_label, from: "Merchandise class"
    assert_selector "select#product_variant_pricing_method option[selected][value='fixed']"
    assert_field "Regular price", with: ""
  end
end
