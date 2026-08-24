# frozen_string_literal: true

module Bibliographic
  module SubjectMatcher
    module_function

    def call(texts)
      Array(texts).filter_map { |raw|
        text = raw.to_s.unicode_normalize(:nfkc).strip
        next if text.blank?

        pattern = text.downcase
        SubjectHeading.assignable.find_by(
          "LOWER(name) = :t OR LOWER(COALESCE(code, '')) = :t",
          t: pattern
        )
      }.uniq
    end

    def rows_for(texts)
      call(texts).map.with_index { |heading, index|
        { "subject_heading_id" => heading.id, "primary" => false, "position" => index }
      }
    end
  end
end
