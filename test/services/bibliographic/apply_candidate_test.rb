# frozen_string_literal: true

require "test_helper"

class Bibliographic::ApplyCandidateTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
    @product = Products::Create.call(
      attributes: {
        name: "Staff Title",
        status: "draft",
        list_price_cents: 2500,
        bibliographic_curated_fields: %w[name list_price_cents]
      },
      actor: @actor,
      industry_identifier: FIXTURE_ISBN13
    )
  end

  test "default apply skips curated fields including list price" do
    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: bibliographic_candidate,
      actor: @actor
    )

    @product.reload
    assert_equal "Staff Title", @product.name
    assert_equal 2500, @product.list_price_cents
    assert_equal "Paperback", @product.binding
    assert_equal "Ace", @product.publisher.name
    assert_equal "isbndb", @product.bibliographic_provider
    assert_equal FIXTURE_ISBN13, @product.bibliographic_provider_key
    assert_includes @product.contributors.map(&:display_name), "Ursula K. Le Guin"
  end

  test "overwrite_curated replaces staff-edited fields" do
    Bibliographic::ApplyCandidate.call(
      product: @product,
      candidate: bibliographic_candidate,
      actor: @actor,
      overwrite_curated: true
    )

    @product.reload
    assert_equal "The Left Hand of Darkness", @product.name
    assert_equal 1699, @product.list_price_cents
  end
end
