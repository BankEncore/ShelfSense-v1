# frozen_string_literal: true

require "test_helper"

class ProductIdentityTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @product = Products::Create.call(
      attributes: { name: "Identity Product", status: "draft" },
      actor: @actor
    )
  end

  test "lookup code is trimmed, uppercased, and nullable when blank" do
    @product.update!(lookup_code: "  shelf-a1  ")
    assert_equal "SHELF-A1", @product.reload.lookup_code

    @product.update!(lookup_code: "   ")
    assert_nil @product.reload.lookup_code
  end

  test "lookup code rejects unsupported characters and excess length" do
    @product.lookup_code = "SHELF A1"
    assert_not @product.valid?
    assert @product.errors[:lookup_code].any?

    @product.lookup_code = "A" * 65
    assert_not @product.valid?
    assert @product.errors[:lookup_code].any?
  end

  test "the database rejects a noncanonical stored lookup code" do
    assert_raises(ActiveRecord::StatementInvalid) do
      @product.update_columns(lookup_code: "lowercase")
    end
  end

  test "two products may share a lookup code" do
    other = Products::Create.call(
      attributes: { name: "Shared", status: "draft" },
      actor: @actor
    )
    @product.update!(lookup_code: "SHARED")
    other.update!(lookup_code: "SHARED")

    assert_equal 2, Product.where(lookup_code: "SHARED").count
  end

  test "industry identifier must be unique and shaped like a GTIN" do
    other = Products::Create.call(
      attributes: { name: "Industry Owner", status: "draft" },
      actor: @actor,
      industry_identifier: external_isbn13
    )

    @product.identifier_writes_enabled = true
    @product.industry_identifier = other.industry_identifier
    assert_not @product.valid?
    assert @product.errors[:industry_identifier].any?

    @product.identifier_writes_enabled = true
    @product.industry_identifier = "97812345"
    assert_not @product.valid?
    assert @product.errors[:industry_identifier].any?
  end

  test "industry identifier cannot be written outside the registry-aware service" do
    @product.industry_identifier = external_isbn13
    assert_not @product.valid?
    assert_includes @product.errors[:industry_identifier],
                    "must be changed through Identifiers::AssignProductIndustry"
  end

  test "primary identifier remains immutable" do
    @product.primary_identifier = shelfsense_222("000000009")
    assert_not @product.valid?
    assert_includes @product.errors[:primary_identifier], "cannot be changed"
  end
end
