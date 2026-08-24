# frozen_string_literal: true

require "test_helper"

class Bibliographic::ApplyCandidateTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @product = Products::Create.call(
      attributes: {
        name: "Staff Title",
        status: "draft",
        list_price_cents: 2500
      },
      actor: @actor,
      industry_identifier: FIXTURE_ISBN13
    )
  end

  test "applies only selected fields and records provider provenance for unchanged values" do
    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: bibliographic_candidate,
      actor: @actor,
      selected_fields: %w[brand_name language_code],
      lock_version: @product.lock_version
    )

    @product.reload
    assert_equal "Staff Title", @product.name
    assert_equal 2500, @product.list_price_cents
    assert_equal "Ace", @product.brand_name
    assert_equal "en", @product.language_code
    assert_nil @product.binding if @product.has_attribute?(:binding)
    assert_equal "isbndb", @product.bibliographic_field_sources.dig("brand_name", "source")
  end

  test "edited selected values receive staff provenance" do
    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: bibliographic_candidate,
      actor: @actor,
      selected_fields: %w[name],
      submitted_values: { "name" => "Edited Title" },
      lock_version: @product.lock_version
    )

    @product.reload
    assert_equal "Edited Title", @product.name
    assert_equal "staff", @product.bibliographic_field_sources.dig("name", "source")
  end

  test "unselected fields stay unchanged" do
    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: bibliographic_candidate,
      actor: @actor,
      selected_fields: %w[imprint],
      lock_version: @product.lock_version
    )

    @product.reload
    assert_equal "Staff Title", @product.name
    assert_equal 2500, @product.list_price_cents
  end

  test "cover download is discarded when product apply rolls back" do
    candidate = bibliographic_candidate
    result = Bibliographic::CoverDownloader::Result.new(
      bytes: [ "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000a49444154789c63f80f00000101000518d84e0000000049454e44ae426082" ].pack("H*"),
      content_type: "image/png",
      filename: "cover.png",
      source_url: candidate.cover_image_url
    )
    stale = @product.lock_version
    Products::Update.call(
      product: @product,
      attributes: { name: "Changed first", lock_version: stale },
      actor: @actor
    )

    stub_cover_download(result) do
      assert_raises(Bibliographic::ApplyCandidate::Error) do
        Bibliographic::ApplyCandidate.call(
          product: @product.reload,
          candidate: candidate,
          actor: @actor,
          selected_fields: %w[cover_image],
          lock_version: stale
        )
      end
    end

    assert_not @product.reload.cover_image.attached?
  end

  test "HTML submitted numeric values keep provider provenance when unchanged" do
    candidate = bibliographic_candidate(series_position: BigDecimal("3"))

    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: candidate,
      actor: @actor,
      selected_fields: %w[page_count list_price_cents series_position release_date industry_identifier],
      submitted_values: {
        "page_count" => "304",
        "list_price_cents" => "$16.99",
        "series_position" => "3.0",
        "release_date" => "1969-01-01",
        "industry_identifier" => "978-0-441-47812-5"
      },
      lock_version: @product.lock_version
    )

    @product.reload
    assert_equal 304, @product.page_count
    assert_equal 1699, @product.list_price_cents
    assert_equal BigDecimal("3"), @product.series_position
    assert_equal Date.new(1969, 1, 1), @product.release_date
    assert_equal FIXTURE_ISBN13, @product.industry_identifier
    %w[page_count list_price_cents series_position release_date industry_identifier].each do |field|
      assert_equal "isbndb", @product.bibliographic_field_sources.dig(field, "source"), field
      assert_equal FIXTURE_ISBN13, @product.bibliographic_field_sources.dig(field, "provider_key"), field
    end
  end

  test "clearing selected scalar and collection fields removes provenance" do
    ProductForms::Catalog.seed!
    SubjectSchemes::Catalog.seed!
    house = SubjectScheme.find_by!(key: "house")
    house.subject_headings.create!(name: "Fiction", active: true)
    candidate = bibliographic_candidate(
      series_position: BigDecimal("1"),
      product_form_code: "PB",
      subjects: [ "Fiction" ]
    )

    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: candidate,
      actor: @actor,
      selected_fields: %w[page_count list_price_cents product_form contributions subjects],
      lock_version: @product.lock_version
    )
    @product.reload
    assert_equal "isbndb", @product.bibliographic_field_sources.dig("page_count", "source")
    assert @product.product_contributions.any?
    assert @product.product_subject_assignments.any?

    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: candidate,
      actor: @actor,
      selected_fields: %w[page_count list_price_cents product_form contributions subjects],
      submitted_values: {
        "page_count" => "",
        "list_price_cents" => "",
        "product_form" => "",
        "contribution_rows" => [ { "display_name" => "", "role" => "author" } ],
        "subject_rows" => []
      },
      lock_version: @product.lock_version
    )

    @product.reload
    assert_nil @product.page_count
    assert_nil @product.list_price_cents
    assert_nil @product.product_form_id
    assert_empty @product.product_contributions
    assert_empty @product.product_subject_assignments
    %w[page_count list_price_cents product_form contributions subjects].each do |field|
      assert_nil @product.bibliographic_field_sources[field], field
    end
  end

  test "records products.enrich with service-confirmed applied fields in the apply transaction" do
    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: bibliographic_candidate,
      actor: @actor,
      selected_fields: %w[page_count],
      submitted_values: { "page_count" => "304" },
      lock_version: @product.lock_version
    )

    event = AuditEvent.where(action: "products.enrich", subject_id: @product.id).last
    assert_equal [ "page_count" ], event.after_values["applied_fields"]
    assert_equal "isbndb", @product.reload.bibliographic_field_sources.dig("page_count", "source")
  end
end
