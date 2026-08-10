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
      actor: @actor,
      identifier_mode: "generate"
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
      actor: @actor,
      identifier_mode: "generate"
    )
    value = product.primary_identifier

    Identifiers::Registry.retire!(value: value)
    row = Identifiers::Registry.find_any(value)

    assert row.retired_at.present?
    assert_nil Identifiers::Registry.find_active(value)
  end

  test "active ownership requires exactly one owner" do
    row = IdentifierRegistry.new(
      value: Identifiers::Ean13.complete("978", "111111111"),
      identifier_kind: "product_primary",
      retired_at: nil
    )
    assert_not row.valid?
    assert_includes row.errors[:base], "active registry rows require exactly one owner"
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
          identifier_mode: "enter",
          external_identifier: external
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
