# frozen_string_literal: true

require "test_helper"

class Bibliographic::LookupCacheTest < ActiveSupport::TestCase
  test "stores candidates and returns them until expiry" do
    candidate = bibliographic_candidate
    Bibliographic::LookupCache.store("isbn:#{FIXTURE_ISBN13}", [ candidate ], ttl: 24.hours)

    found = Bibliographic::LookupCache.fetch("isbn:#{FIXTURE_ISBN13}")
    assert_equal 1, found.length
    assert_equal candidate.isbn13, found.first.isbn13
    assert_equal candidate.title, found.first.title
    assert_equal candidate.list_price_cents, found.first.list_price_cents
  end

  test "expired rows are cache misses" do
    candidate = bibliographic_candidate
    Bibliographic::LookupCache.store("isbn:#{FIXTURE_ISBN13}", [ candidate ], ttl: 1.hour)

    travel 61.minutes do
      assert_nil Bibliographic::LookupCache.fetch("isbn:#{FIXTURE_ISBN13}")
    end
  end
end
