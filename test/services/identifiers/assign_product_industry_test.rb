# frozen_string_literal: true

require "test_helper"

class Identifiers::AssignProductIndustryTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @product = Products::Create.call(
      attributes: { name: "Product industry", status: "draft" },
      actor: @actor
    )
    @industry = unique_industry_identifier
    @replacement = unique_industry_identifier
  end

  test "assigns the product industry identifier through the registry" do
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: @industry)

    assert_equal @industry, @product.reload.industry_identifier
    row = IdentifierRegistry.find_by!(value: @industry)
    assert_equal "product_industry", row.identifier_kind
    assert_equal @product.id, row.product_id
    assert_nil row.product_variant_id
    assert_nil row.retired_at
  end

  test "replaces the identifier and retires the previous registry row" do
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: @industry)
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: @replacement)

    assert_equal @replacement, @product.reload.industry_identifier
    assert IdentifierRegistry.find_by!(value: @industry).retired_at.present?
    assert_nil IdentifierRegistry.find_by!(value: @replacement).retired_at
  end

  test "clears the identifier and retires the registry row" do
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: @industry)
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: nil)

    assert_nil @product.reload.industry_identifier
    assert IdentifierRegistry.find_by!(value: @industry).retired_at.present?
  end

  test "rejects the reserved 222 namespace" do
    error = assert_raises(Identifiers::AssignProductIndustry::Error) do
      Identifiers::AssignProductIndustry.call(product: @product, raw_value: shelfsense_222("000000123"))
    end

    assert_match(/reserved 222/i, error.message)
    assert_nil @product.reload.industry_identifier
  end

  test "rejects a value already reserved for another owner" do
    variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { variant_type: "standard", status: "draft", industry_identifier: @industry }
    )

    other = Products::Create.call(
      attributes: { name: "Collides", status: "draft" },
      actor: @actor
    )
    error = assert_raises(Identifiers::AssignProductIndustry::Error) do
      Identifiers::AssignProductIndustry.call(product: other, raw_value: @industry)
    end

    assert_match(/already reserved/i, error.message)
    assert_nil other.reload.industry_identifier
    assert_equal @industry, variant.reload.industry_identifier
  end

  test "products update routes industry changes through the registry-aware service" do
    Products::Update.call(
      product: @product,
      actor: @actor,
      attributes: { industry_identifier: @industry, lock_version: @product.lock_version }
    )
    Products::Update.call(
      product: @product.reload,
      actor: @actor,
      attributes: {
        industry_identifier: @replacement,
        lookup_code: "shelf-b2",
        name: "Renamed",
        lock_version: @product.lock_version
      }
    )

    @product.reload
    assert_equal @replacement, @product.industry_identifier
    assert_equal "SHELF-B2", @product.lookup_code
    assert_equal "Renamed", @product.name
    assert IdentifierRegistry.find_by!(value: @industry).retired_at.present?
  end

  test "a stale lock_version rejects the change and rolls back the registry" do
    Identifiers::AssignProductIndustry.call(product: @product, raw_value: @industry)
    @product.reload
    stale = @product.lock_version
    @product.update!(name: "Concurrent edit")

    assert_raises(ActiveRecord::StaleObjectError) do
      Products::Update.call(
        product: Product.find(@product.id),
        actor: @actor,
        attributes: { industry_identifier: @replacement, lock_version: stale }
      )
    end

    @product.reload
    assert_equal @industry, @product.industry_identifier
    assert_nil IdentifierRegistry.find_by(value: @replacement)
    assert_nil IdentifierRegistry.find_by!(value: @industry).retired_at
  end

  private

  def unique_industry_identifier
    20.times do
      value = Identifiers::Ean13.complete("978", format("%09d", SecureRandom.random_number(1_000_000_000)))
      next if IdentifierRegistry.exists?(value: value)
      next if Product.exists?(industry_identifier: value)
      next if ProductVariant.exists?(industry_identifier: value)

      return value
    end
    raise "unable to allocate unique industry identifier for test"
  end
end
