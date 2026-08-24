# frozen_string_literal: true

require "test_helper"

class Bibliographic::SearchTest < ActiveSupport::TestCase
  setup do
    @actor = actor_user
  end

  test "a local industry identifier opens the existing product" do
    product = Products::Create.call(
      attributes: { name: "Local Book", status: "draft" },
      actor: @actor,
      industry_identifier: FIXTURE_ISBN13
    )
    provider = FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])

    stub_bibliographic_provider(provider) do
      result = Bibliographic::Search.call(query: FIXTURE_ISBN13)
      assert_equal :existing, result.status
      assert_equal product.id, result.existing_product.id
      assert_empty provider.calls
    end
  end

  test "an unknown ISBN fetches once and reuses the cache" do
    provider = FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])

    stub_bibliographic_provider(provider) do
      first = Bibliographic::Search.call(query: FIXTURE_ISBN13)
      assert_equal :candidates, first.status
      assert_equal FIXTURE_ISBN13, first.candidates.first.isbn13

      second = Bibliographic::Search.call(query: FIXTURE_ISBN13)
      assert_equal :candidates, second.status
      assert_equal 1, provider.calls.length
    end
  end

  test "title search includes local suggestions without blocking create" do
    local = Products::Create.call(
      attributes: { name: "Left Hand Mug", status: "draft" },
      actor: @actor
    )
    provider = FakeIsbnDbProvider.new(candidates: [ bibliographic_candidate ])

    stub_bibliographic_provider(provider) do
      result = Bibliographic::Search.call(query: "Left Hand")
      assert_equal :candidates, result.status
      assert_includes result.local_suggestions.map(&:id), local.id
      assert_equal FIXTURE_ISBN13, result.candidates.first.isbn13
    end
  end

  test "missing provider configuration is unavailable" do
    stub_bibliographic_provider(FakeIsbnDbProvider.new(configured: false, error: Bibliographic::HttpClient::Unavailable.new("ISBNdb is not configured"))) do
      result = Bibliographic::Search.call(query: FIXTURE_ISBN13)
      assert_equal :unavailable, result.status
      assert_match(/not configured/i, result.message)
    end
  end

  test "timeouts surface as unavailable" do
    stub_bibliographic_provider(
      FakeIsbnDbProvider.new(error: Bibliographic::HttpClient::TimeoutError.new("ISBNdb request timed out"))
    ) do
      result = Bibliographic::Search.call(query: FIXTURE_ISBN13)
      assert_equal :unavailable, result.status
      assert_match(/timed out/i, result.message)
    end
  end
end
