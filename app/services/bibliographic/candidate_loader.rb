# frozen_string_literal: true

module Bibliographic
  module CandidateLoader
    module_function

    def call(candidate_id: nil, isbn13: nil, lookup_key: nil)
      if candidate_id.present?
        return Bibliographic::LookupCache.fetch_candidate(candidate_id)
      end

      isbn = begin
        Identifiers::Normalizer.normalize(isbn13, allow_shelfsense_222: false) if isbn13.present?
      rescue Identifiers::NormalizationError
        isbn13.to_s.presence
      end

      keys = [ lookup_key.presence ]
      keys << "isbn:#{isbn}" if isbn.present?
      keys.compact.uniq.each do |key|
        list = Bibliographic::LookupCache.fetch(key)
        if isbn.present?
          match = Array(list).find { |candidate| candidate.isbn13 == isbn }
          return match if match
        elsif Array(list).one?
          return list.first
        end
      end
      nil
    end
  end
end
