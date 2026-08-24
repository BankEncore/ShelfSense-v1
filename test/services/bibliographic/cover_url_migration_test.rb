# frozen_string_literal: true

require "test_helper"

class Bibliographic::CoverUrlMigrationTest < ActiveSupport::TestCase
  TINY_PNG = [ "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000a49444154789c63f80f00000101000518d84e0000000049454e44ae426082" ].pack("H*")

  test "failed cover URL migration stays recoverable and does not raise" do
    skip "cover_image_url column already dropped" unless Product.column_names.include?("cover_image_url")

    report = Bibliographic::CoverUrlMigration.call
    assert_kind_of Array, report
  end

  test "reviewed apply can attach a cover after a failed URL migration" do
    actor = actor_user
    product = Products::Create.call(attributes: { name: "Cover later", status: "draft" }, actor: actor)
    candidate = bibliographic_candidate(cover_image_url: "https://images.isbndb.com/covers/ok.png")
    Bibliographic::LookupCache.store("isbn:#{candidate.isbn13}", [ candidate ], ttl: 1.hour)

    result = Bibliographic::CoverDownloader::Result.new(
      bytes: TINY_PNG,
      content_type: "image/png",
      filename: "cover.png",
      source_url: candidate.cover_image_url
    )

    stub_cover_download(result) do
      Bibliographic::ApplyCandidate.call(
        product: product,
        candidate: candidate,
        actor: actor,
        selected_fields: %w[cover_image],
        lock_version: product.lock_version
      )
    end

    assert product.reload.cover_image.attached?
  end
end
