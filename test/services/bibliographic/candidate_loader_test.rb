# frozen_string_literal: true

require "test_helper"

class Bibliographic::CandidateLoaderTest < ActiveSupport::TestCase
  test "loads a cached candidate by id and treats unknown or expired ids as missing" do
    candidate = bibliographic_candidate
    Bibliographic::LookupCache.store("isbn:#{candidate.isbn13}", [ candidate ], ttl: 1.hour)

    found = Bibliographic::CandidateLoader.call(candidate_id: candidate.candidate_id)
    assert_equal candidate.isbn13, found.isbn13

    assert_nil Bibliographic::CandidateLoader.call(candidate_id: SecureRandom.uuid)
    assert_nil Bibliographic::CandidateLoader.call(candidate_id: "tampered-not-a-cache-key")

    travel 2.hours do
      assert_nil Bibliographic::CandidateLoader.call(candidate_id: candidate.candidate_id)
    end
  end
end
