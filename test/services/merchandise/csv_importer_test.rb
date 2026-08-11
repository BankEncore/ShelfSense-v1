# frozen_string_literal: true

require "test_helper"
require "stringio"

class Merchandise::CsvImporterTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @tax = tax_class(code: "books")
    @dept = department(code: "new_books", default_tax_class: @tax)
    @klass = merchandise_class(code: "book", pricing_method: "fixed", default_standard_department: @dept)
    @used_klass = merchandise_class(
      code: "used_book",
      pricing_method: "fixed",
      used_merchandise_allowed: true,
      default_standard_department: @dept,
      default_used_department: @dept
    )
    @condition = merchandise_condition(code: "like_new")
  end

  test "matches product by normalized primary_identifier" do
    existing = Products::Create.call(
      attributes: { name: "Original", status: "draft" },
      actor: @actor,
      identifier_mode: "enter",
      external_identifier: external_isbn13
    )

    result = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier
      978-123456789-#{Identifiers::Ean13.check_digit("978123456789")},Renamed,false
    CSV

    assert_equal 0, result.created_products
    assert_equal 1, result.updated_products
    assert_empty result.errors
    assert_equal "Renamed", existing.reload.name
  end

  test "generate path creates a 222 product" do
    result = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier
      ,Generated Import,true
    CSV

    assert_equal 1, result.created_products
    assert_empty result.errors
    product = Product.order(:created_at).last
    assert_match(/\A222\d{10}\z/, product.primary_identifier)
  end

  test "re-import by assigned 222 updates the existing product" do
    product = Products::Create.call(
      attributes: { name: "Generated", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )

    result = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier
      #{product.primary_identifier},Updated Generated,false
    CSV

    assert_equal 0, result.created_products
    assert_equal 1, result.updated_products
    assert_empty result.errors
    assert_equal "Updated Generated", product.reload.name
  end

  test "matches variant by sku or industry identifier" do
    product = Products::Create.call(
      attributes: { name: "With variants", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    industry = Identifiers::Ean13.complete("978", "555555555")
    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: {
        variant_type: "standard",
        name: "First",
        industry_identifier: industry
      }
    )

    by_sku = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier,sku,variant_name
      #{product.primary_identifier},With variants,false,#{variant.sku},By SKU
    CSV
    assert_equal 1, by_sku.updated_variants
    assert_equal "By SKU", variant.reload.name

    by_industry = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier,industry_identifier,variant_name
      #{product.primary_identifier},With variants,false,#{industry},By Industry
    CSV
    assert_equal 1, by_industry.updated_variants
    assert_equal "By Industry", variant.reload.name
  end

  test "insufficient identity error when variant fields lack type and match keys" do
    product = Products::Create.call(
      attributes: { name: "Identity", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    unknown_industry = Identifiers::Ean13.complete("978", "777777777")

    result = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier,industry_identifier,variant_name
      #{product.primary_identifier},Identity,false,#{unknown_industry},Orphan
    CSV

    assert_equal 1, result.errors.size
    assert_match(/insufficient identity/i, result.errors.first[:message])
  end

  test "rejects assigning caller SKU to new variant" do
    product = Products::Create.call(
      attributes: { name: "Caller SKU", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )
    fake_sku = Identifiers::Ean13.complete("221", "888888888")

    result = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier,sku,variant_type,variant_name
      #{product.primary_identifier},Caller SKU,false,#{fake_sku},standard,Should Fail
    CSV

    assert_equal 1, result.errors.size
    assert_match(/caller-assigned SKU|not accepted/i, result.errors.first[:message])
    assert_nil ProductVariant.find_by(sku: fake_sku)
  end

  test "creates used variant with condition and standard without" do
    product = Products::Create.call(
      attributes: { name: "Typed", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )

    result = import_csv(<<~CSV)
      primary_identifier,name,generate_primary_identifier,variant_type,variant_condition_code,merchandise_class_code,regular_price_cents
      #{product.primary_identifier},Typed,false,used,like_new,used_book,1200
    CSV
    assert_empty result.errors
    assert_equal 1, result.created_variants
    used = product.product_variants.used.first
    assert used.present?
    assert_equal @condition.id, used.merchandise_condition_id
  end

  private

  def import_csv(text)
    Merchandise::CsvImporter.call(io: StringIO.new(text), actor: @actor)
  end
end
