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

    assert_nil product.publisher_id
    assert_nil product.binding
    assert_nil product.page_count
    assert_equal "ShelfBrand", product.brand_name
    assert_empty product.product_contributions
  end

  test "publisher find-or-create reuses a normalized name" do
    first = Publisher.find_or_create_normalized!("  Ace  Books ")
    second = Publisher.find_or_create_normalized!("ACE BOOKS")

    assert_equal first.id, second.id
    assert_equal "ace books", first.name_normalized
  end

  test "contribution uniqueness is per product, contributor, and role" do
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
      contributor: product.contributors.first,
      role: "author",
      position: 9
    )
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save(validate: false)
    end
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

  test "updating a bibliographic field marks it curated" do
    product = Products::Create.call(
      attributes: { name: "To Curate", status: "draft", binding: "Paperback" },
      actor: @actor
    )

    Products::Update.call(
      product: product,
      attributes: { binding: "Hardcover", lock_version: product.lock_version },
      actor: @actor
    )

    assert_includes product.reload.bibliographic_curated_fields, "binding"
  end
end
