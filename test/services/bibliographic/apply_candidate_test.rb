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
end
