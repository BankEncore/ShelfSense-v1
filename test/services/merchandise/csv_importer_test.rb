# frozen_string_literal: true

require "test_helper"
require "stringio"

class Merchandise::CsvImporterTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @tax = tax_class(code: "books")
    @override_tax = tax_class(code: "override_tax")
    @dept = department(code: "new_books")
    @klass = merchandise_class(code: "book", pricing_method: "fixed", department: @dept, default_tax_class: @tax)
    @used_klass = merchandise_class(
      code: "used_book",
      pricing_method: "fixed",
      used_merchandise_allowed: true,
      department: @dept,
      default_tax_class: @tax
    )
    @condition = merchandise_condition(code: "like_new")
  end

  test "rows without a product key always create a generated 222 product" do
    result = import_csv(<<~CSV)
      name
      Generated Import
    CSV

    assert_equal 1, result.created_products
    assert_empty result.errors
    product = Product.order(:created_at).last
    assert_match(/\A222\d{10}\z/, product.primary_identifier)
  end

  test "import cannot assign a primary identifier" do
    unknown = Identifiers::Ean13.complete("978", "123456789")

    result = import_csv(<<~CSV)
      product_primary_identifier,name
      #{unknown},Should Fail
    CSV

    assert_equal 1, result.errors.size
    assert_match(/unknown product_primary_identifier/i, result.errors.first[:message])
    assert_nil Product.find_by(primary_identifier: unknown)
  end

  test "re-import by assigned 222 updates the existing product" do
    product = Products::Create.call(
      attributes: { name: "Generated", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name
      #{product.primary_identifier},Updated Generated
    CSV

    assert_equal 0, result.created_products
    assert_equal 1, result.updated_products
    assert_empty result.errors
    assert_equal "Updated Generated", product.reload.name
  end

  test "product industry identifier creates then updates the same product" do
    isbn10 = "0306406152"
    normalized = Identifiers::Ean13.complete("978", "030640615")

    created = import_csv(<<~CSV)
      product_industry_identifier,name
      #{isbn10},Industry Book
    CSV
    assert_empty created.errors
    assert_equal 1, created.created_products
    product = Product.find_by!(industry_identifier: normalized)
    assert_equal "product_industry", Identifiers::Registry.find_active(normalized).identifier_kind

    updated = import_csv(<<~CSV)
      product_industry_identifier,name
      #{normalized},Industry Book Renamed
    CSV
    assert_empty updated.errors
    assert_equal 1, updated.updated_products
    assert_equal "Industry Book Renamed", product.reload.name
    assert_equal "staff", product.bibliographic_field_sources.dig("name", "source")
    assert_nil product.bibliographic_field_sources["subtitle"]
  end

  test "lookup code locates one product and stores uppercase" do
    result = import_csv(<<~CSV)
      product_lookup_code,name
      shelf-a1,Lookup Book
    CSV
    assert_empty result.errors
    product = Product.find_by!(lookup_code: "SHELF-A1")

    again = import_csv(<<~CSV)
      product_lookup_code,name
      SHELF-A1,Lookup Book Renamed
    CSV
    assert_empty again.errors
    assert_equal 1, again.updated_products
    assert_equal "Lookup Book Renamed", product.reload.name
  end

  test "a lookup code matching several products fails the group" do
    Products::Create.call(attributes: { name: "Shared One", status: "draft" }, actor: @actor, lookup_code: "SHARED")
    Products::Create.call(attributes: { name: "Shared Two", status: "draft" }, actor: @actor, lookup_code: "SHARED")

    result = import_csv(<<~CSV)
      product_lookup_code,name
      SHARED,Ambiguous
    CSV

    assert_equal 1, result.errors.size
    assert_match(/matches 2 products/i, result.errors.first[:message])
    assert_nil Product.find_by(name: "Ambiguous")
  end

  test "two new rows sharing a lookup code create two products" do
    result = import_csv(<<~CSV)
      product_lookup_code,name
      SHARED-NEW,Product One
      SHARED-NEW,Product Two
    CSV

    assert_empty result.errors
    assert_equal 2, result.created_products
    products = Product.where(lookup_code: "SHARED-NEW").order(:name)
    assert_equal [ "Product One", "Product Two" ], products.map(&:name)
    assert_equal 2, products.map(&:primary_identifier).uniq.size
  end

  test "blank identity cells leave the industry identifier and lookup code untouched" do
    industry = Identifiers::Ean13.complete("978", "030640615")
    product = Products::Create.call(
      attributes: { name: "Keeps Identity", status: "draft" },
      actor: @actor,
      industry_identifier: industry,
      lookup_code: "KEEP-1"
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,product_industry_identifier,product_lookup_code,name
      #{product.primary_identifier},,,Renamed Only
    CSV

    assert_empty result.errors
    product.reload
    assert_equal "Renamed Only", product.name
    assert_equal industry, product.industry_identifier
    assert_equal "KEEP-1", product.lookup_code
    assert_nil Identifiers::Registry.find_active(industry).retired_at
  end

  test "matches variant by sku or industry identifier" do
    product = Products::Create.call(
      attributes: { name: "With variants", status: "draft" },
      actor: @actor
    )
    industry = Identifiers::Ean13.complete("978", "555555555")
    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { status: "draft",
        variant_type: "standard",
        name: "First",
        industry_identifier: industry
      }
    )

    by_sku = import_csv(<<~CSV)
      product_primary_identifier,name,sku,variant_name
      #{product.primary_identifier},With variants,#{variant.sku},By SKU
    CSV
    assert_equal 1, by_sku.updated_variants
    assert_equal "Standard", variant.reload.name

    by_industry = import_csv(<<~CSV)
      product_primary_identifier,name,industry_identifier,variant_name
      #{product.primary_identifier},With variants,#{industry},By Industry
    CSV
    assert_equal 1, by_industry.updated_variants
    assert_equal "Standard", variant.reload.name
  end

  test "insufficient identity error when variant fields lack type and match keys" do
    product = Products::Create.call(
      attributes: { name: "Identity", status: "draft" },
      actor: @actor
    )
    unknown_industry = Identifiers::Ean13.complete("978", "777777777")

    result = import_csv(<<~CSV)
      product_primary_identifier,name,industry_identifier,variant_name
      #{product.primary_identifier},Identity,#{unknown_industry},Orphan
    CSV

    assert_equal 1, result.errors.size
    assert_match(/insufficient identity/i, result.errors.first[:message])
  end

  test "rejects assigning caller SKU to new variant" do
    product = Products::Create.call(
      attributes: { name: "Caller SKU", status: "draft" },
      actor: @actor
    )
    fake_sku = Identifiers::Ean13.complete("221", "888888888")

    result = import_csv(<<~CSV)
      product_primary_identifier,name,sku,variant_type,variant_name
      #{product.primary_identifier},Caller SKU,#{fake_sku},standard,Should Fail
    CSV

    assert_equal 1, result.errors.size
    assert_match(/caller-assigned SKU|not accepted/i, result.errors.first[:message])
    assert_nil ProductVariant.find_by(sku: fake_sku)
  end

  test "creates used variant with condition and standard without" do
    product = Products::Create.call(
      attributes: { name: "Typed", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name,variant_type,variant_condition_code,merchandise_class_code,regular_price_cents,status
      #{product.primary_identifier},Typed,used,like_new,used_book,1200,draft
    CSV
    assert_empty result.errors
    assert_equal 1, result.created_variants
    used = product.product_variants.used.first
    assert used.present?
    assert_equal @condition.id, used.merchandise_condition_id
  end

  test "copies explicit operational values and keeps an explicit false supplier returnable" do
    product = Products::Create.call(
      attributes: { name: "Ops", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name,variant_type,merchandise_class_code,pricing_method,target_margin_bps,supplier_returnable,tax_class_override_code,regular_price_cents,status
      #{product.primary_identifier},Ops,standard,book,list_price,4200,false,override_tax,1500,draft
    CSV

    assert_empty result.errors
    variant = product.product_variants.first
    assert_equal "list_price", variant.pricing_method
    assert_equal 4_200, variant.target_margin_bps
    assert_equal false, variant.supplier_returnable
    assert_equal @override_tax.id, variant.tax_class_override_id
  end

  test "blank tax_class_override_code inherits the merchandise class default" do
    product = Products::Create.call(
      attributes: { name: "Inherit", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name,variant_type,merchandise_class_code,tax_class_override_code,regular_price_cents,status
      #{product.primary_identifier},Inherit,standard,book,,1500,draft
    CSV

    assert_empty result.errors
    variant = product.product_variants.first
    assert_nil variant.tax_class_override_id
    assert_equal @tax.id, variant.effective_tax_class.id
  end

  test "rolls back the product group when a later variant row fails" do
    product = Products::Create.call(
      attributes: { name: "Grouped", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name,variant_type,variant_condition_code,merchandise_class_code,regular_price_cents,status
      #{product.primary_identifier},Grouped Renamed,standard,,book,1500,draft
      #{product.primary_identifier},Grouped Renamed,used,,book,900,draft
    CSV

    assert_equal 1, result.errors.size
    assert_match(/variant_condition_code is required/i, result.errors.first[:message])
    assert_equal 0, result.created_products
    assert_equal 0, result.created_variants
    assert_equal "Grouped", product.reload.name
    assert_equal 0, product.product_variants.count
  end

  test "rejects unknown reference codes instead of defaulting" do
    product = Products::Create.call(
      attributes: { name: "Refs", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name,variant_type,merchandise_class_code,regular_price_cents,status
      #{product.primary_identifier},Refs,standard,missing_class,1500,draft
    CSV

    assert_equal 1, result.errors.size
    assert_match(/unknown merchandise_class_code/i, result.errors.first[:message])
    assert_equal 0, product.product_variants.count
  end

  test "keyless rows are create-only across reimports" do
    first = import_csv(<<~CSV)
      name
      Generated A
    CSV
    second = import_csv(<<~CSV)
      name
      Generated A
    CSV

    assert_equal 1, first.created_products
    assert_equal 1, second.created_products
    assert_equal 2, Product.where(name: "Generated A").count
  end

  test "import updates create record-level audit events" do
    product = Products::Create.call(
      attributes: { name: "Audit Me", status: "draft" },
      actor: @actor
    )

    result = import_csv(<<~CSV)
      product_primary_identifier,name
      #{product.primary_identifier},Audited Name
    CSV

    assert_empty result.errors
    assert AuditEvent.where(action: "products.update", subject_type: "Product", subject_id: product.id).exists?
    assert_equal "Audited Name", product.reload.name
  end

  private

  def import_csv(text)
    Merchandise::CsvImporter.call(io: StringIO.new(text), actor: @actor)
  end
end
