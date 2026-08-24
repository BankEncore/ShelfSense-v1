# frozen_string_literal: true

module Bibliographic
  module CandidateLoader
    module_function

    def call(isbn13:, lookup_key: nil)
      isbn = begin
        Identifiers::Normalizer.normalize(isbn13, allow_shelfsense_222: false) if isbn13.present?
      rescue Identifiers::NormalizationError
        isbn13.to_s.presence
      end
      return if isbn.blank?

      keys = [ lookup_key.presence, "isbn:#{isbn}" ].compact.uniq
      keys.each do |key|
        list = Bibliographic::LookupCache.fetch(key)
        match = Array(list).find { |candidate| candidate.isbn13 == isbn }
        return match if match
      end
      nil
    end
  end
end
