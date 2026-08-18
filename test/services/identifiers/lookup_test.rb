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
    @used_klass = merchandise_class(
      code: "used_book",
      pricing_method: "fixed",
      used_merchandise_allowed: true,
      default_standard_department: @dept,
      default_used_department: @dept
    )
    @like_new = merchandise_condition(code: "like_new", price_adjustment_bps: 6_000)
    @product = Products::Create.call(
      attributes: { name: "Lookup Product", status: "active" },
      actor: @actor,
      identifier_mode: "enter",
      external_identifier: external_isbn13
    )
  end

  test "resolves variant by sku" do
    variant = create_sellable_standard!(name: "SKU variant")
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
    first = create_sellable_standard!(name: "First")
    second = create_sellable_used!(name: "Second")
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

  test "resolves inventory unit without treating the used variant sku as a unit" do
    used = create_sellable_used!(name: "Used lookup")
    Inventory::AdjustmentReasons.seed!
    acquisition = Inventory::PostAdjustment.call(
      store: Store.first!,
      product_variant: used,
      adjustment_reason: AdjustmentReason.find_by!(code: "opening_inventory"),
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 400
    )
    unit = acquisition.inventory_unit

    sku_result = Identifiers::Lookup.call(used.sku)
    assert_equal :variant, sku_result.status
    assert_equal used.id, sku_result.variant.id
    assert_nil sku_result.inventory_unit

    unit_result = Identifiers::Lookup.call(unit.unit_identifier)
    assert_equal :inventory_unit, unit_result.status
    assert_equal unit.id, unit_result.inventory_unit.id
    assert_equal used.id, unit_result.variant.id
    assert_equal @product.id, unit_result.product.id
  end

  private

  def create_sellable_standard!(name:)
    ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        variant_type: "standard",
        name: name,
        merchandise_class_id: @klass.id,
        department_id: @dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_500,
        status: "active"
      }
    )
  end

  def create_sellable_used!(name:)
    ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        variant_type: "used",
        name: name,
        merchandise_condition_id: @like_new.id,
        merchandise_class_id: @used_klass.id,
        department_id: @dept.id,
        tax_class_id: @tax.id,
        regular_price_cents: 1_200,
        status: "active"
      }
    )
  end
end
