# frozen_string_literal: true

module Bibliographic
  class LookupCache
    ISBN_TTL = 24.hours
    TITLE_TTL = 1.hour

    def self.fetch(lookup_key, provider: "isbndb")
      row = BibliographicLookupCache.find_by(lookup_key: lookup_key, provider: provider)
      return if row.nil? || row.expired?

      Array(row.payload).map { |hash| Bibliographic::Candidate.from_h(hash) }
    end

    def self.store(lookup_key, candidates, provider: "isbndb", ttl:)
      payload = Array(candidates).map(&:to_h)
      now = Time.current
      row = BibliographicLookupCache.find_or_initialize_by(lookup_key: lookup_key, provider: provider)
      row.payload = payload
      row.fetched_at = now
      row.expires_at = now + ttl
      row.save!
      candidates
    end
  end
end
