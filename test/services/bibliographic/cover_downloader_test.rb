# frozen_string_literal: true

require "test_helper"

class Bibliographic::CoverDownloaderTest < ActiveSupport::TestCase
  TINY_PNG = [ "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000a49444154789c63f80f00000101000518d84e0000000049454e44ae426082" ].pack("H*")

  test "blocks a redirect to a private address" do
    public_ip = ->(_host) { [ IPAddr.new("93.184.216.34") ] }
    private_ip = ->(_host) { [ IPAddr.new("127.0.0.1") ] }
    resolver = ->(host) { host == "images.isbndb.com" ? public_ip.call(host) : private_ip.call(host) }
    transport = ->(uri) {
      if uri.host == "images.isbndb.com"
        [ "302", { "location" => "https://127.0.0.1/secret" }, "" ]
      else
        [ "200", {}, TINY_PNG ]
      end
    }

    error = assert_raises(Bibliographic::CoverDownloader::Error) do
      Bibliographic::CoverDownloader.call(
        url: "https://images.isbndb.com/cover.png",
        allowed_urls: [ "https://images.isbndb.com/cover.png" ],
        resolver: resolver,
        transport: transport
      )
    end
    assert_match(/public address|not allowed/i, error.message)
  end

  test "rejects oversized and non-image bodies" do
    oversized = "x" * (Bibliographic::CoverDownloader::MAX_BYTES + 1)
    error = assert_raises(Bibliographic::CoverDownloader::Error) do
      Bibliographic::CoverDownloader.call(
        url: "https://images.isbndb.com/cover.png",
        allowed_urls: [ "https://images.isbndb.com/cover.png" ],
        resolver: ->(_host) { [ IPAddr.new("93.184.216.34") ] },
        transport: ->(_uri) { [ "200", { "content-length" => oversized.bytesize.to_s }, oversized ] }
      )
    end
    assert_match(/too large/i, error.message)

    error = assert_raises(Bibliographic::CoverDownloader::Error) do
      Bibliographic::CoverDownloader.call(
        url: "https://images.isbndb.com/cover.png",
        allowed_urls: [ "https://images.isbndb.com/cover.png" ],
        resolver: ->(_host) { [ IPAddr.new("93.184.216.34") ] },
        transport: ->(_uri) { [ "200", { "content-type" => "image/jpeg" }, "<html>not an image</html>" ] }
      )
    end
    assert_match(/accepted image|not an accepted/i, error.message)
  end

  test "rejects a misleading content type when bytes are not an image" do
    error = assert_raises(Bibliographic::CoverDownloader::Error) do
      Bibliographic::CoverDownloader.call(
        url: "https://images.isbndb.com/cover.jpg",
        allowed_urls: [ "https://images.isbndb.com/cover.jpg" ],
        resolver: ->(_host) { [ IPAddr.new("93.184.216.34") ] },
        transport: ->(_uri) { [ "200", { "content-type" => "image/jpeg" }, "GIF89a fake" ] }
      )
    end
    assert_match(/accepted image|not an accepted/i, error.message)
  end

  test "times out through the transport" do
    error = assert_raises(Bibliographic::CoverDownloader::Error) do
      Bibliographic::CoverDownloader.call(
        url: "https://images.isbndb.com/cover.png",
        allowed_urls: [ "https://images.isbndb.com/cover.png" ],
        resolver: ->(_host) { [ IPAddr.new("93.184.216.34") ] },
        transport: ->(_uri) { raise Net::ReadTimeout }
      )
    end
    assert_match(/timed out|failed/i, error.message)
  end

  test "staff upload replaces a provider cover" do
    actor = actor_user
    product = Products::Create.call(
      attributes: { name: "Covered", status: "draft" },
      actor: actor
    )
    product.cover_image.attach(io: StringIO.new(TINY_PNG), filename: "old.png", content_type: "image/png")
    old_id = product.cover_image.blob.id

    Products::Update.call(
      product: product,
      attributes: {
        lock_version: product.lock_version,
        cover_image: { io: StringIO.new(TINY_PNG), filename: "new.png", content_type: "image/png" }
      },
      actor: actor
    )
    product.reload
    assert product.cover_image.attached?
    assert_not_equal old_id, product.cover_image.blob.id
    assert_equal "staff", product.bibliographic_field_sources.dig("cover_image", "source")
  end
end
