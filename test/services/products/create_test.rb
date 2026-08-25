# frozen_string_literal: true

require "test_helper"

class Products::CreateTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "always allocates a generated 222 primary identifier" do
    product = Products::Create.call(
      attributes: { name: "Generated", status: "draft" },
      actor: @actor
    )

    assert_match(/\A222\d{10}\z/, product.primary_identifier)
    assert Identifiers::Ean13.valid?(product.primary_identifier)
    row = Identifiers::Registry.find_active(product.primary_identifier)
    assert_equal "product_primary", row.identifier_kind
    assert_equal product.id, row.product_id
  end

  test "reserves an optional normalized industry identifier as product_industry" do
    product = Products::Create.call(
      attributes: { name: "Entered Book", status: "draft" },
      actor: @actor,
      industry_identifier: "978-123456789-#{Identifiers::Ean13.check_digit("978123456789")}"
    )

    expected = Identifiers::Ean13.complete("978", "123456789")
    assert_equal expected, product.industry_identifier
    row = Identifiers::Registry.find_active(expected)
    assert_equal "product_industry", row.identifier_kind
    assert_equal product.id, row.product_id
  end

  test "normalizes an ISBN-10 industry identifier to a Bookland ISBN-13" do
    product = Products::Create.call(
      attributes: { name: "ISBN-10 Book", status: "draft" },
      actor: @actor,
      industry_identifier: "0306406152"
    )

    assert_equal Identifiers::Ean13.complete("978", "030640615"), product.industry_identifier
  end

  test "rejects an entered industry identifier in the reserved 222 namespace" do
    value = shelfsense_222
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Bad 222", status: "draft" },
        actor: @actor,
        industry_identifier: value
      )
    end
    assert_match(/reserved 222/i, error.message)
    assert_nil Product.find_by(name: "Bad 222")
  end

  test "rejects an industry identifier already reserved by another product" do
    external = external_isbn13
    Products::Create.call(
      attributes: { name: "First", status: "draft" },
      actor: @actor,
      industry_identifier: external
    )

    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Second", status: "draft" },
        actor: @actor,
        industry_identifier: external
      )
    end
    assert_match(/already reserved|taken|unique/i, error.message)
    assert_equal 1, Product.where(industry_identifier: external).count
  end

  test "stores an optional lookup code uppercase and outside the registry" do
    product = Products::Create.call(
      attributes: { name: "Lookup", status: "draft" },
      actor: @actor,
      lookup_code: " shelf-a1 "
    )

    assert_equal "SHELF-A1", product.lookup_code
    assert_nil IdentifierRegistry.find_by(value: "SHELF-A1")
  end

  test "permits a lookup code already used by another product" do
    first = Products::Create.call(
      attributes: { name: "Shared One", status: "draft" },
      actor: @actor,
      lookup_code: "SHARED"
    )
    second = Products::Create.call(
      attributes: { name: "Shared Two", status: "draft" },
      actor: @actor,
      lookup_code: "shared"
    )

    assert_equal "SHARED", first.lookup_code
    assert_equal "SHARED", second.lookup_code
    assert_equal 2, Product.where(lookup_code: "SHARED").count
  end

  test "rejects lookup codes with unsupported characters" do
    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: { name: "Bad code", status: "draft" },
        actor: @actor,
        lookup_code: "SHELF A1"
      )
    end
    assert_match(/lookup code/i, error.message)
  end

  test "audits the created identity without an identifier mode" do
    product = Products::Create.call(
      attributes: { name: "Audited", status: "draft" },
      actor: @actor,
      industry_identifier: external_isbn13,
      lookup_code: "AUD-1"
    )

    event = AuditEvent.where(action: "products.create", subject_id: product.id).last
    assert_equal product.primary_identifier, event.after_values["primary_identifier"]
    assert_equal product.industry_identifier, event.after_values["industry_identifier"]
    assert_equal "AUD-1", event.after_values["lookup_code"]
    assert_not event.after_values.key?("identifier_source")
    assert_not AuditEvent.exists?(action: "products.enrich", subject_id: product.id)
  end

  test "persists optional bibliographic facts without requiring them" do
    product = Products::Create.call(
      attributes: {
        name: "Bibliographic Book",
        status: "draft",
        brand_name: "Tor",
        contribution_rows: [ { "display_name" => "N. K. Jemisin", "role" => "author" } ]
      },
      actor: @actor
    )

    assert_equal "Tor", product.brand_name
    assert_equal "N. K. Jemisin", product.product_contributions.first.display_name
  end

  test "staff cover uploads are validated from bytes and purged on create rollback" do
    png = [ "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de0000000a49444154789c63f80f00000101000518d84e0000000049454e44ae426082" ].pack("H*")
    before = ActiveStorage::Blob.count

    error = assert_raises(Products::Create::Error) do
      Products::Create.call(
        attributes: {
          name: "Bad cover",
          status: "draft",
          cover_image: { io: StringIO.new("<script>nope</script>"), filename: "cover.png", content_type: "image/png" }
        },
        actor: @actor
      )
    end
    assert_match(/accepted image/i, error.message)
    assert_equal before, ActiveStorage::Blob.count

    product = Products::Create.call(
      attributes: {
        name: "Good cover",
        status: "draft",
        cover_image: { io: StringIO.new(png), filename: "cover.png", content_type: "image/png" }
      },
      actor: @actor
    )
    assert product.cover_image.attached?
    assert_equal "image/png", product.cover_image.blob.content_type
  end

  test "cover blobs are purged when a later unexpected error rolls back create" do
    before = ActiveStorage::Blob.count

    stub_audit_recorder_failure do
      assert_raises(RuntimeError) do
        Products::Create.call(
          attributes: {
            name: "Audit fail cover",
            status: "draft",
            cover_image: { io: StringIO.new(TINY_COVER_PNG), filename: "cover.png", content_type: "image/png" }
          },
          actor: @actor
        )
      end
    end

    assert_nil Product.find_by(name: "Audit fail cover")
    assert_equal before, ActiveStorage::Blob.count
  end
end
