# frozen_string_literal: true

require "test_helper"

class Identifiers::LookupTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @tax = tax_class(code: "books")
    @dept = department(code: "new_books")
    @klass = merchandise_class(
      code: "book",
      pricing_method: "fixed",
      department: @dept,
      default_tax_class: @tax
    )
    @used_klass = merchandise_class(
      code: "used_book",
      pricing_method: "fixed",
      used_merchandise_allowed: true,
      department: @dept,
      default_tax_class: @tax
    )
    @like_new = merchandise_condition(code: "like_new", price_adjustment_bps: 6_000)
    @product = Products::Create.call(
      attributes: { name: "Lookup Product", status: "active" },
      actor: @actor,
      industry_identifier: external_isbn13
    )
  end

  test "resolves variant by sku" do
    variant = create_sellable_standard!(name: "SKU variant")
    result = Identifiers::Lookup.call(variant.sku)

    assert_equal :variant, result.status
    assert_equal variant.id, result.variant.id
    assert_equal @product.id, result.product.id
  end

  test "resolves the product for a 222 primary identifier without any variants" do
    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :product, result.status
    assert_equal @product.id, result.product.id
    assert_nil result.variant
    assert_empty result.variants
  end

  test "product industry identifier enters the same product path as the 222 primary" do
    variant = create_sellable_standard!(name: "Industry variant")
    result = Identifiers::Lookup.call(@product.industry_identifier)

    assert_equal :product, result.status
    assert_equal @product.id, result.product.id
    assert_equal [ variant.id ], result.variants.map(&:id)
  end

  test "matching does not filter variants by POS sellability" do
    sellable = create_sellable_standard!(name: "Sellable")
    draft = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: {
        status: "draft",
        variant_type: "used",
        merchandise_condition_id: @like_new.id,
        merchandise_class_id: @used_klass.id,
        regular_price_cents: 1_200
      }
    )
    assert_not draft.sellable?

    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :product, result.status
    assert_equal [ draft.id, sellable.id ].sort, result.variants.map(&:id).sort
  end

  test "returns all variants for a product identifier with several variants" do
    first = create_sellable_standard!(name: "First")
    second = create_sellable_used!(name: "Second")
    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :product, result.status
    assert_equal @product.id, result.product.id
    assert_equal [ first.id, second.id ].sort, result.variants.map(&:id).sort
  end

  test "returns not_found for an unknown identifier with no lookup-code match" do
    unknown = Identifiers::Ean13.complete("978", "999999999")
    result = Identifiers::Lookup.call(unknown)

    assert_equal :not_found, result.status
  end

  test "returns retired for a tombstoned identifier" do
    Identifiers::Registry.retire!(value: @product.primary_identifier)
    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :retired, result.status
  end

  test "a retired registry row does not fall through to a matching lookup code" do
    @product.update_columns(lookup_code: @product.primary_identifier)
    Identifiers::Registry.retire!(value: @product.primary_identifier)

    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :retired, result.status
    assert_nil result.product
  end

  test "returns invalid for input that is neither a GTIN nor a lookup code" do
    result = Identifiers::Lookup.call("not an identifier")

    assert_equal :invalid, result.status
  end

  test "returns invalid for blank input" do
    assert_equal :invalid, Identifiers::Lookup.call("  ").status
  end

  test "a unique lookup code resolves to that product" do
    @product.update!(lookup_code: "SHELF-A1")

    result = Identifiers::Lookup.call("shelf-a1")

    assert_equal :product, result.status
    assert_equal @product.id, result.product.id
  end

  test "a shared lookup code returns multiple_products deterministically" do
    @product.update!(lookup_code: "SHARED")
    other = Products::Create.call(
      attributes: { name: "Another Lookup Product", status: "active" },
      actor: @actor,
      lookup_code: "SHARED"
    )

    result = Identifiers::Lookup.call("shared")

    assert_equal :multiple_products, result.status
    assert_equal [ other.id, @product.id ], result.products.map(&:id)
    assert_nil result.product
  end

  test "an active registry row wins over an identical lookup code on another product" do
    other = Products::Create.call(
      attributes: { name: "Lookup Code Twin", status: "active" },
      actor: @actor,
      lookup_code: @product.primary_identifier
    )

    result = Identifiers::Lookup.call(@product.primary_identifier)

    assert_equal :product, result.status
    assert_equal @product.id, result.product.id
    assert_not_equal other.id, result.product.id
  end

  test "a valid GTIN with no registry row may still match a lookup code" do
    unregistered = Identifiers::Ean13.complete("978", "444444444")
    other = Products::Create.call(
      attributes: { name: "GTIN Lookup Code", status: "active" },
      actor: @actor,
      lookup_code: unregistered
    )

    result = Identifiers::Lookup.call(unregistered)

    assert_equal :product, result.status
    assert_equal other.id, result.product.id
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
        regular_price_cents: 1_200,
        status: "active"
      }
    )
  end
end
