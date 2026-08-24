# frozen_string_literal: true

module Bibliographic
  module ContributorRole
    module_function

    MAP = {
      "author" => "author",
      "aut" => "author",
      "editor" => "editor",
      "edt" => "editor",
      "illustrator" => "illustrator",
      "ill" => "illustrator",
      "translator" => "translator",
      "trl" => "translator",
      "photographer" => "photographer",
      "pht" => "photographer",
      "narrator" => "narrator",
      "nrt" => "narrator",
      "other" => "other"
    }.freeze

    class Unknown < StandardError; end

    def map!(raw)
      value = raw.to_s.strip
      return "author" if value.blank?

      mapped = MAP[value.downcase]
      raise Unknown, "unknown contributor role #{value}" if mapped.blank?

      mapped
    end
  end
end
