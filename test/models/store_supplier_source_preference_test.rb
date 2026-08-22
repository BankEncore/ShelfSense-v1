# frozen_string_literal: true

require "test_helper"

class StoreSupplierSourcePreferenceTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @tax = tax_class(code: "pref_tax_#{SecureRandom.hex(2)}")
    @standard = pos_sellable_variant(actor: @actor, tax_class: @tax)
    @used = pos_sellable_variant(actor: @actor, tax_class: @tax, variant_type: "used", name: "Used Pref")
    @supplier = Supplier.create!(name: "Pref Supplier", code: "pref_#{SecureRandom.hex(2)}")
    @source = SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @standard,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 300
    )
  end

  test "requires source to match variant" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Other Variant")
    preference = StoreSupplierSourcePreference.new(
      store: @store,
      product_variant: other,
      supplier_variant_source: @source
    )
    assert_not preference.valid?
    assert_includes preference.errors[:supplier_variant_source_id], "must belong to the same product variant"
  end

  test "rejects used variants" do
    used_source = SupplierVariantSource.new(
      supplier: @supplier,
      product_variant: @used,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 200
    )
    # Prefer validating preference against a standard-only source path: used source itself is invalid.
    preference = StoreSupplierSourcePreference.new(
      store: @store,
      product_variant: @used,
      supplier_variant_source: @source
    )
    assert_not preference.valid?
    assert(
      preference.errors[:product_variant_id].include?("must be a Standard variant") ||
        preference.errors[:supplier_variant_source_id].include?("must belong to the same product variant")
    )
    assert_not used_source.valid?
  end
end
