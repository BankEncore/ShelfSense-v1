# frozen_string_literal: true

module Bibliographic
  # Provider-boundary language names and ISO 639-1/639-2 codes → stored two-letter codes.
  module LanguageCodes
    module_function

    MAP = {
      "en" => "en",
      "eng" => "en",
      "english" => "en",
      "fr" => "fr",
      "fre" => "fr",
      "fra" => "fr",
      "french" => "fr",
      "es" => "es",
      "spa" => "es",
      "spanish" => "es",
      "de" => "de",
      "ger" => "de",
      "deu" => "de",
      "german" => "de"
    }.freeze

    def normalize(raw)
      return if raw.blank?

      MAP[raw.to_s.strip.downcase]
    end
  end
end
