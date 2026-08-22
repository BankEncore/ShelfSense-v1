# frozen_string_literal: true

require "test_helper"

class Purchasing::PreferredSourceResolverTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @actor = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @tax = tax_class(code: "psr_tax_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    @supplier_a = Supplier.create!(name: "Supplier A", code: "psr_a_#{SecureRandom.hex(2)}")
    @supplier_b = Supplier.create!(name: "Supplier B", code: "psr_b_#{SecureRandom.hex(2)}")
    @org_preferred = SupplierVariantSource.create!(
      supplier: @supplier_a,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    @store_source = SupplierVariantSource.create!(
      supplier: @supplier_b,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 450
    )
  end

  test "returns organization preferred when no store override" do
    resolved = Purchasing::PreferredSourceResolver.call(store: @store, product_variant: @variant)
    assert_equal @org_preferred, resolved
  end

  test "store override wins over organization preferred" do
    StoreSupplierSourcePreference.create!(
      store: @store,
      product_variant: @variant,
      supplier_variant_source: @store_source
    )
    resolved = Purchasing::PreferredSourceResolver.call(store: @store, product_variant: @variant)
    assert_equal @store_source, resolved
  end

  test "returns nil when no preferred source exists" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "No Source")
    assert_nil Purchasing::PreferredSourceResolver.call(store: @store, product_variant: other)
  end

  test "ignores inactive store override source and falls back to org preferred" do
    StoreSupplierSourcePreference.create!(
      store: @store,
      product_variant: @variant,
      supplier_variant_source: @store_source
    )
    @store_source.update!(active: false)
    resolved = Purchasing::PreferredSourceResolver.call(store: @store, product_variant: @variant)
    assert_equal @org_preferred, resolved
  end
end
