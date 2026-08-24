# frozen_string_literal: true

module Bibliographic
  module NameNormalizer
    module_function

    def call(raw)
      value = raw.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ").downcase
      value.presence
    end
  end
end
