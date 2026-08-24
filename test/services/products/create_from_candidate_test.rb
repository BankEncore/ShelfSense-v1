# frozen_string_literal: true

require "test_helper"

class Products::CreateFromCandidateTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "allocates a 222 primary and reserves the candidate industry identifier" do
    product = Products::CreateFromCandidate.call(
      candidate: bibliographic_candidate,
      actor: @actor
    )

    assert_match(/\A222\d{10}\z/, product.primary_identifier)
    assert_equal FIXTURE_ISBN13, product.industry_identifier
    assert_equal "The Left Hand of Darkness", product.name
    assert_equal "Ace", product.publisher.name
    assert_equal 1699, product.list_price_cents
    assert_equal "isbndb", product.bibliographic_provider
    row = Identifiers::Registry.find_active(FIXTURE_ISBN13)
    assert_equal "product_industry", row.identifier_kind
    assert_equal product.id, row.product_id
    assert AuditEvent.exists?(action: "products.enrich", subject_id: product.id)
  end

  test "marks only staff diffs from the candidate as curated" do
    product = Products::CreateFromCandidate.call(
      candidate: bibliographic_candidate,
      actor: @actor,
      attributes: {
        name: "Local display title",
        subtitle: "50th Anniversary Edition",
        list_price_cents: 1699,
        publisher_name: "Ace",
        contribution_rows: [ { "display_name" => "Ursula K. Le Guin", "role" => "author" } ]
      }
    )

    assert_equal [ "name" ], product.bibliographic_curated_fields
  end

  test "falls back to candidate contributors when submitted rows are blank" do
    product = Products::CreateFromCandidate.call(
      candidate: bibliographic_candidate,
      actor: @actor,
      attributes: {
        contribution_rows: [
          { "display_name" => "", "role" => "author" },
          { "display_name" => "  ", "role" => "illustrator" }
        ]
      }
    )

    assert_equal [ "Ursula K. Le Guin" ], product.product_contributions.map { |row| row.contributor.display_name }
    assert_not_includes product.bibliographic_curated_fields, "contributions"
  end

  test "rejects a candidate whose ISBN is already on a product" do
    Products::Create.call(
      attributes: { name: "Existing", status: "draft" },
      actor: @actor,
      industry_identifier: FIXTURE_ISBN13
    )

    error = assert_raises(Products::CreateFromCandidate::Error) do
      Products::CreateFromCandidate.call(candidate: bibliographic_candidate, actor: @actor)
    end
    assert_match(/already uses/i, error.message)
  end
end
