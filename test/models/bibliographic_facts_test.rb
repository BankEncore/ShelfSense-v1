# frozen_string_literal: true

require "test_helper"

class BibliographicFactsTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "non-book products still create with blank bibliographic fields" do
    product = Products::Create.call(
      attributes: { name: "Bookmark tin", status: "draft", brand_name: "ShelfBrand" },
      actor: @actor
    )

    assert_nil product.page_count
    assert_equal "ShelfBrand", product.brand_name
    assert_empty product.product_contributions
    assert_equal "staff", product.bibliographic_field_sources.dig("brand_name", "source")
    assert_equal "staff", product.bibliographic_field_sources.dig("name", "source")
    assert_nil product.bibliographic_field_sources["status"]
  end

  test "contribution uniqueness is per product, display name, and role" do
    product = Products::Create.call(
      attributes: {
        name: "Illustrated",
        status: "draft",
        contribution_rows: [
          { "display_name" => "Ada Lovelace", "role" => "author" },
          { "display_name" => "Ada Lovelace", "role" => "illustrator" }
        ]
      },
      actor: @actor
    )

    assert_equal 2, product.product_contributions.count
    duplicate = product.product_contributions.build(
      display_name: "Ada Lovelace",
      role: "author",
      position: 9
    )
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
  end

  test "unknown contributor roles are rejected" do
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: {
          name: "Unknown role",
          status: "draft",
          contribution_rows: [ { "display_name" => "Ada", "role" => "foreword" } ]
        },
        actor: @actor
      )
    end
    assert_match(/unknown contributor role/i, error.message)
  end

  test "optimistic locking still rejects a stale product update" do
    product = Products::Create.call(
      attributes: { name: "Locked", status: "draft" },
      actor: @actor
    )
    stale = product.lock_version
    Products::Update.call(
      product: product,
      attributes: { name: "First writer", lock_version: stale },
      actor: @actor
    )

    assert_raises(ActiveRecord::StaleObjectError) do
      Products::Update.call(
        product: product.reload,
        attributes: { name: "Second writer", lock_version: stale },
        actor: @actor
      )
    end
  end

  test "updating one bibliographic field records staff provenance without rewriting others" do
    product = Products::Create.call(
      attributes: { name: "To Curate", status: "draft", brand_name: "Ace", imprint: "Tor" },
      actor: @actor
    )
    original_brand = product.bibliographic_field_sources["brand_name"]

    Products::Update.call(
      product: product,
      attributes: { imprint: "Orb", lock_version: product.lock_version },
      actor: @actor
    )

    product.reload
    assert_equal "staff", product.bibliographic_field_sources.dig("imprint", "source")
    assert_equal original_brand, product.bibliographic_field_sources["brand_name"]
  end

  test "unknown provenance keys are rejected" do
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: {
          name: "Bad provenance",
          status: "draft",
          bibliographic_field_sources: { "not_a_field" => { "source" => "staff", "applied_at" => Time.current.iso8601 } }
        },
        actor: @actor
      )
    end
    assert_match(/unknown bibliographic field/i, error.message)
  end
end
