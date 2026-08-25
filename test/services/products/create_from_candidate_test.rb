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
    assert_equal "Ace", product.brand_name
    assert_equal "50th Anniversary", product.product_model
    assert_equal 1699, product.list_price_cents
    assert_not product.cover_image.attached?
    assert_nil product.binding if product.has_attribute?(:binding)
    assert_equal "isbndb", product.bibliographic_provider
    assert_equal "isbndb", product.bibliographic_field_sources.dig("brand_name", "source")
    assert_equal "en", product.language_code
    assert product.release_date_approximate?
    assert_equal Date.new(1969, 1, 1), product.release_date
    row = Identifiers::Registry.find_active(FIXTURE_ISBN13)
    assert_equal "product_industry", row.identifier_kind
    assert_equal product.id, row.product_id
    assert AuditEvent.exists?(action: "products.enrich", subject_id: product.id)
  end

  test "marks only staff diffs from the candidate as staff provenance" do
    product = Products::CreateFromCandidate.call(
      candidate: bibliographic_candidate,
      actor: @actor,
      attributes: {
        name: "Local display title",
        subtitle: "50th Anniversary Edition",
        list_price_cents: 1699,
        brand_name: "Ace",
        contribution_rows: [ { "display_name" => "Ursula K. Le Guin", "role" => "author" } ]
      }
    )

    assert_equal "staff", product.bibliographic_field_sources.dig("name", "source")
    assert_equal "isbndb", product.bibliographic_field_sources.dig("subtitle", "source")
    assert_equal "isbndb", product.bibliographic_field_sources.dig("contributions", "source")
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

    assert_equal [ "Ursula K. Le Guin" ], product.product_contributions.map(&:display_name)
    assert_equal "isbndb", product.bibliographic_field_sources.dig("contributions", "source")
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

  test "creates an ISBN-less candidate with a provenance-only provider key" do
    candidate = bibliographic_candidate(isbn13: nil, provider_key: nil, title: "No ISBN Title")
    assert_match(/\Aisbndb:candidate:/, candidate.provider_key)

    product = Products::CreateFromCandidate.call(candidate: candidate, actor: @actor)

    assert_equal "No ISBN Title", product.name
    assert_nil product.industry_identifier
    assert_nil product.bibliographic_provider_key
    assert_equal "isbndb", product.bibliographic_field_sources.dig("name", "source")
    assert_equal candidate.provider_key, product.bibliographic_field_sources.dig("name", "provider_key")
    refute_equal candidate.provider_key, product.primary_identifier
    assert AuditEvent.exists?(action: "products.enrich", subject_id: product.id)
  end

  test "attaches a staff cover upload and records staff provenance" do
    product = Products::CreateFromCandidate.call(
      candidate: bibliographic_candidate,
      actor: @actor,
      attributes: {
        cover_image: { io: StringIO.new(TINY_COVER_PNG), filename: "cover.png", content_type: "image/png" }
      }
    )

    assert product.cover_image.attached?
    assert_equal "image/png", product.cover_image.blob.content_type
    assert_equal "staff", product.bibliographic_field_sources.dig("cover_image", "source")
    assert_nil product.bibliographic_field_sources.dig("cover_image", "provider_key")
    assert_equal "isbndb", product.bibliographic_field_sources.dig("name", "source")
  end
end
