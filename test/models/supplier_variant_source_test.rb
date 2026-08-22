# frozen_string_literal: true

require "test_helper"

class SupplierVariantSourceTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "svs_tax_#{SecureRandom.hex(2)}")
    @standard = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Standard Title")
    @used = pos_sellable_variant(actor: @actor, tax_class: @tax, variant_type: "used", name: "Used Title")
    @supplier = Supplier.create!(name: "Test Supplier", code: "test_supplier_#{SecureRandom.hex(2)}")
  end

  test "rejects used variants" do
    source = SupplierVariantSource.new(
      supplier: @supplier,
      product_variant: @used,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500
    )
    assert_not source.valid?
    assert_includes source.errors[:product_variant_id], "must be a Standard variant"
  end

  test "rejects non-inventory standard variants" do
    non_inventory = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      pricing_method: "open_price",
      name: "Non Inventory"
    )
    source = SupplierVariantSource.new(
      supplier: @supplier,
      product_variant: non_inventory,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 100
    )
    assert_not source.valid?
    assert_includes source.errors[:product_variant_id], "must be inventory-bearing"
  end

  test "enforces pricing method exclusivity for direct unit cost" do
    source = SupplierVariantSource.new(
      supplier: @supplier,
      product_variant: @standard,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 750,
      supplier_list_price_cents: 1000,
      discount_basis_points: 2500
    )
    assert source.valid?
    assert_nil source.supplier_list_price_cents
    assert_nil source.discount_basis_points
    assert_equal 750, source.expected_unit_cost_cents
  end

  test "requires list price and discount for discount_from_list" do
    source = SupplierVariantSource.new(
      supplier: @supplier,
      product_variant: @standard,
      pricing_method: "discount_from_list"
    )
    assert_not source.valid?
    assert_includes source.errors[:supplier_list_price_cents], "is required for discount from list"
    assert_includes source.errors[:discount_basis_points], "is required for discount from list"
  end

  test "derives expected unit cost from discount" do
    source = SupplierVariantSource.new(
      supplier: @supplier,
      product_variant: @standard,
      pricing_method: "discount_from_list",
      supplier_list_price_cents: 1000,
      discount_basis_points: 2500
    )
    assert source.valid?
    assert_equal 750, source.derived_expected_unit_cost_cents
  end

  test "allows only one active organization preferred source per variant" do
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @standard,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    other_supplier = Supplier.create!(name: "Other", code: "other_#{SecureRandom.hex(2)}")
    conflict = SupplierVariantSource.new(
      supplier: other_supplier,
      product_variant: @standard,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 600,
      organization_preferred: true
    )
    assert_not conflict.valid?
    assert_includes conflict.errors[:organization_preferred],
                    "at most one active organization-preferred source is allowed per variant"
  end

  test "normalizes blank supplier item number to nil" do
    source = SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @standard,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400,
      supplier_item_number: "  "
    )
    assert_nil source.supplier_item_number
  end
end
