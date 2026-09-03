# frozen_string_literal: true

require "test_helper"

class Identifiers::GeneratorAndRegistryTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "generates 222 and 221 identifiers with valid check digits" do
    product_id = Identifiers::Generator.next_ean13!("222")
    sku = Identifiers::Generator.next_ean13!("221")

    assert_match(/\A222\d{10}\z/, product_id)
    assert_match(/\A221\d{10}\z/, sku)
    assert Identifiers::Ean13.valid?(product_id)
    assert Identifiers::Ean13.valid?(sku)
  end

  test "reserve raises on conflict" do
    product = Products::Create.call(
      attributes: { name: "Reserved", status: "draft" },
      actor: @actor
    )

    error = assert_raises(Identifiers::Registry::ConflictError) do
      Identifiers::Registry.reserve!(
        value: product.primary_identifier,
        kind: "product_primary",
        product: product
      )
    end
    assert_match(/already reserved/i, error.message)
  end

  test "retire marks registry row inactive while retaining the value" do
    product = Products::Create.call(
      attributes: { name: "Retire me", status: "draft" },
      actor: @actor
    )
    value = product.primary_identifier

    Identifiers::Registry.retire!(value: value)
    row = Identifiers::Registry.find_any(value)

    assert row.retired_at.present?
    assert_nil Identifiers::Registry.find_active(value)
  end

  test "active product_primary requires a product owner only" do
    row = IdentifierRegistry.new(
      value: Identifiers::Ean13.complete("978", "111111111"),
      identifier_kind: "product_primary",
      retired_at: nil
    )
    assert_not row.valid?
    assert_includes row.errors[:product_id], "is required for active product_primary rows"
  end

  test "active variant_sku rejects product ownership" do
    product = Products::Create.call(
      attributes: { name: "Owner mismatch", status: "draft" },
      actor: @actor
    )
    row = IdentifierRegistry.new(
      value: Identifiers::Ean13.complete("221", "333333333"),
      identifier_kind: "variant_sku",
      product: product,
      retired_at: nil
    )
    assert_not row.valid?
    assert_includes row.errors[:product_variant_id], "is required for active variant_sku rows"
    assert_includes row.errors[:product_id], "must be blank for variant_sku rows"
  end

  test "database enforces kind-specific registry ownership" do
    product = Products::Create.call(
      attributes: { name: "DB owner", status: "draft" },
      actor: @actor
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      IdentifierRegistry.insert!({
        id: SecureRandom.uuid_v7,
        value: Identifiers::Ean13.complete("221", "444444444"),
        identifier_kind: "variant_sku",
        product_id: product.id,
        product_variant_id: nil,
        retired_at: nil,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "retired registry rows may not have two owners" do
    product = Products::Create.call(
      attributes: { name: "Dual owner", status: "draft" },
      actor: @actor
    )
    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { status: "draft",  variant_type: "standard" }
    )

    row = IdentifierRegistry.new(
      value: Identifiers::Ean13.complete("978", "555555555"),
      identifier_kind: "variant_industry",
      product: product,
      product_variant: variant,
      retired_at: Time.current
    )
    assert_not row.valid?
    assert_includes row.errors[:base], "registry rows may have at most one owner"

    assert_raises(ActiveRecord::StatementInvalid) do
      IdentifierRegistry.insert!({
        id: SecureRandom.uuid_v7,
        value: Identifiers::Ean13.complete("978", "666666666"),
        identifier_kind: "variant_industry",
        product_id: product.id,
        product_variant_id: variant.id,
        retired_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "direct product and variant persistence cannot bypass identifier services" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Product.create!(
        name: "Bypass",
        primary_identifier: Identifiers::Ean13.complete("978", "777777777"),
        status: "draft"
      )
    end

    product = Products::Create.call(
      attributes: { name: "Guarded", status: "draft" },
      actor: @actor
    )
    assert_raises(ActiveRecord::RecordInvalid) do
      product.update!(primary_identifier: Identifiers::Ean13.complete("978", "888888888"))
    end

    variant = ProductVariants::Create.call(
      product: product,
      actor: @actor,
      attributes: { status: "draft",  variant_type: "standard" }
    )
    assert_raises(ActiveRecord::RecordInvalid) do
      variant.update!(industry_identifier: Identifiers::Ean13.complete("978", "999999999"))
    end
    assert_nil variant.reload.industry_identifier
  end

  test "failed product create rolls back reservation" do
    external = external_isbn13
    before_products = Product.count
    before_registry = IdentifierRegistry.count

    original = Audit::Recorder.method(:record!)
    Audit::Recorder.define_singleton_method(:record!) do |**_|
      raise "simulated audit failure"
    end

    begin
      assert_raises(RuntimeError) do
        Products::Create.call(
          attributes: { name: "Rollback", status: "draft" },
          actor: @actor,
          industry_identifier: external
        )
      end
    ensure
      Audit::Recorder.define_singleton_method(:record!, original)
    end

    assert_equal before_products, Product.count
    assert_equal before_registry, IdentifierRegistry.count
    assert_nil Identifiers::Registry.find_any(external)
  end
end
