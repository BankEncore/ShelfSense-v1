# frozen_string_literal: true

require "test_helper"

class Identifiers::LookupTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @tax = tax_class(code: "books")
    @dept = department(code: "new_books", default_tax_class: @tax)
    @klass = merchandise_class(
      code: "book",
      pricing_method: "fixed",
      default_standard_department: @dept
    )
    @condition = merchandise_condition(code: "new")
    @condition_used = merchandise_condition(code: "used", department_basis: "used", price_adjustment_bps: 6_000)
    @klass.update!(used_merchandise_allowed: true, default_used_department: @dept)
    @product = Products::Create.call(
      attributes: { name: "Lookup Product", status: "active" },
      actor: @actor,
      identifier_mode: "enter",
      external_identifier: external_isbn13
    )
  end

  test "resolves variant by sku" do
    variant = create_sellable_variant!(name: "SKU variant")
    result = Identifiers::Lookup.call(variant.sku)

    assert_equal :variant, result.status
    assert_equal variant.id, result.variant.id
    assert_equal @product.id, result.product.id
  end

  test "resolves product when no sellable variants exist" do
    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :product, result.status
    assert_equal @product.id, result.product.id
    assert_nil result.variant
  end

  test "resolves multi_variant when multiple sellable variants exist" do
    first = create_sellable_variant!(name: "First", condition: @condition)
    second = create_sellable_variant!(name: "Second", condition: @condition_used)
    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :multi_variant, result.status
    assert_equal @product.id, result.product.id
    assert_equal [ first.id, second.id ].sort, result.variants.map(&:id).sort
  end

  test "returns not_found for unknown identifier" do
    unknown = Identifiers::Ean13.complete("978", "999999999")
    result = Identifiers::Lookup.call(unknown)

    assert_equal :not_found, result.status
  end

  test "returns retired for tombstoned identifier" do
    Identifiers::Registry.retire!(value: @product.primary_identifier)
    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :retired, result.status
  end

  test "returns invalid for bad input" do
    result = Identifiers::Lookup.call("not-an-identifier")

    assert_equal :invalid, result.status
    assert_match(/13 digits|blank|check digit/i, result.message)
  end

  private

  def create_sellable_variant!(name:, condition: @condition)
    ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        name: name,
        merchandise_condition_id: condition.id,
        merchandise_class_id: @klass.id,
        department_id: @dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_500,
        status: "active"
      }
    )
  end
end
