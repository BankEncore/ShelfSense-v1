# frozen_string_literal: true

module Codes
  module Normalizer
    module_function

    FORMAT = /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/

    def normalize(raw)
      value = ActiveSupport::Inflector.transliterate(raw.to_s)
      value = value.downcase
      value = value.gsub(/[^a-z0-9]+/, "_")
      value = value.gsub(/\A_+|_+\z/, "")
      value = value.gsub(/_+/, "_")
      value
    end

    def normalize!(raw)
      value = normalize(raw)
      raise ArgumentError, "code is blank after normalization" if value.blank?
      raise ArgumentError, "code has invalid format" unless value.match?(FORMAT)

      value
    end
  end
end
