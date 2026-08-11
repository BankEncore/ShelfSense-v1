# frozen_string_literal: true

require "test_helper"

class Products::CreateTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "enter mode stores normalized external identifier" do
    product = Products::Create.call(
      attributes: { name: "Entered Book", status: "draft" },
      actor: @actor,
      identifier_mode: "enter",
      external_identifier: "978-123456789-#{Identifiers::Ean13.check_digit("978123456789")}"
    )

    expected = Identifiers::Ean13.complete("978", "123456789")
    assert_equal expected, product.primary_identifier
    assert Identifiers::Registry.find_active(expected)
    assert_equal "product_primary", Identifiers::Registry.find_active(expected).identifier_kind
  end

  test "generate mode allocates a 222 identifier" do
    product = Products::Create.call(
      attributes: { name: "Generated", status: "draft" },
      actor: @actor,
      identifier_mode: "generate"
    )

    assert_match(/\A222\d{10}\z/, product.primary_identifier)
    assert Identifiers::Ean13.valid?(product.primary_identifier)
  end

  test "rejects when neither enter nor generate is chosen" do
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Missing mode", status: "draft" },
        actor: @actor,
        identifier_mode: "none"
      )
    end
    assert_match(/enter or generate/i, error.message)
  end

  test "rejects entered 222 namespace" do
    value = shelfsense_222
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Bad 222", status: "draft" },
        actor: @actor,
        identifier_mode: "enter",
        external_identifier: value
      )
    end
    assert_match(/reserved 222/i, error.message)
    assert_nil Product.find_by(primary_identifier: value)
  end

  test "concurrent-style conflict on duplicate entered identifier" do
    external = external_isbn13
    Products::Create.call(
      attributes: { name: "First", status: "draft" },
      actor: @actor,
      identifier_mode: "enter",
      external_identifier: external
    )

    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Second", status: "draft" },
        actor: @actor,
        identifier_mode: "enter",
        external_identifier: external
      )
    end
    assert_match(/already reserved|taken|unique/i, error.message)
    assert_equal 1, Product.where(primary_identifier: external).count
  end
end
