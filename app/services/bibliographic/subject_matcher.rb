# frozen_string_literal: true

module Bibliographic
  module SubjectMatcher
    module_function

    BISAC_CODE = /\A[A-Z]{3}\d{6}\z/i

    def call(texts)
      Array(texts).filter_map { |raw|
        text = raw.to_s.unicode_normalize(:nfkc).strip
        next if text.blank?

        match_one(text)
      }.uniq
    end

    def rows_for(texts)
      call(texts).map.with_index { |heading, index|
        { "subject_heading_id" => heading.id, "primary" => false, "position" => index }
      }
    end

    def match_one(text)
      if text.match?(BISAC_CODE)
        scheme = SubjectScheme.find_by(key: "bisac")
        return if scheme.nil?

        scheme.subject_headings.assignable.find_by("LOWER(code) = ?", text.downcase)
      else
        scheme = SubjectScheme.find_by(key: "house")
        return if scheme.nil?

        scheme.subject_headings.assignable.find_by("LOWER(name) = ?", text.downcase)
      end
    end
  end
end
