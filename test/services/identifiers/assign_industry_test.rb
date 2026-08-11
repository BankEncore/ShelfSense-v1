# frozen_string_literal: true

require "test_helper"

class Identifiers::AssignIndustryTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @product = Products::Create.call(
      attributes: { name: "Industry product", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    @variant = ProductVariants::Create.call(
      product: @product,
      actor: @actor,
      attributes: { variant_type: "standard", status: "draft" }
    )
    @industry = unique_industry_identifier
    @replacement = unique_industry_identifier
  end

  test "assigns industry identifier through the registry" do
    Identifiers::AssignIndustry.call(variant: @variant, raw_value: @industry)

    assert_equal @industry, @variant.reload.industry_identifier
    row = IdentifierRegistry.find_by!(value: @industry)
    assert_equal "variant_industry", row.identifier_kind
    assert_equal @variant.id, row.product_variant_id
    assert_nil row.product_id
    assert_nil row.retired_at
  end

  test "replaces industry identifier and retires the previous registry row" do
    Identifiers::AssignIndustry.call(variant: @variant, raw_value: @industry)
    Identifiers::AssignIndustry.call(variant: @variant, raw_value: @replacement)

    assert_equal @replacement, @variant.reload.industry_identifier
    assert IdentifierRegistry.find_by!(value: @industry).retired_at.present?
    assert_nil IdentifierRegistry.find_by!(value: @replacement).retired_at
  end

  test "clears industry identifier and retires the registry row" do
    Identifiers::AssignIndustry.call(variant: @variant, raw_value: @industry)
    Identifiers::AssignIndustry.call(variant: @variant, raw_value: nil)

    assert_nil @variant.reload.industry_identifier
    assert IdentifierRegistry.find_by!(value: @industry).retired_at.present?
  end

  test "product variant update routes industry changes through assign industry" do
    ProductVariants::Update.call(
      variant: @variant,
      actor: @actor,
      attributes: { industry_identifier: @industry }
    )
    ProductVariants::Update.call(
      variant: @variant.reload,
      actor: @actor,
      attributes: { industry_identifier: @replacement, name: "Renamed" }
    )

    @variant.reload
    assert_equal @replacement, @variant.industry_identifier
    assert_equal "Renamed", @variant.name
    assert IdentifierRegistry.find_by!(value: @industry).retired_at.present?
    assert_operator AuditEvent.where(
      action: "product_variants.update",
      subject_type: "ProductVariant",
      subject_id: @variant.id
    ).count, :>=, 2
  end

  private

  def unique_industry_identifier
    20.times do
      value = Identifiers::Ean13.complete("978", format("%09d", SecureRandom.random_number(1_000_000_000)))
      next if value == @variant.sku
      next if IdentifierRegistry.exists?(value: value)
      next if ProductVariant.exists?(industry_identifier: value)

      return value
    end
    raise "unable to allocate unique industry identifier for test"
  end
end
