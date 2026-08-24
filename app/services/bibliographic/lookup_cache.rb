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

    def self.fetch_candidate(candidate_id)
      return if candidate_id.blank?

      fetch("candidate:#{candidate_id}")&.first
    end

    def self.store(lookup_key, candidates, provider: "isbndb", ttl:)
      payload = Array(candidates).map(&:to_h)
      now = Time.current
      persist(lookup_key, payload, provider: provider, fetched_at: now, expires_at: now + ttl)
      Array(candidates).each do |candidate|
        persist(
          "candidate:#{candidate.candidate_id}",
          [ candidate.to_h ],
          provider: provider,
          fetched_at: now,
          expires_at: now + ttl
        )
      end
      candidates
    end

    def self.persist(lookup_key, payload, provider:, fetched_at:, expires_at:)
      row = BibliographicLookupCache.find_or_initialize_by(lookup_key: lookup_key, provider: provider)
      row.payload = payload
      row.fetched_at = fetched_at
      row.expires_at = expires_at
      row.save!
    end
  end
end
