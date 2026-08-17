# frozen_string_literal: true

require "digest"

module Idempotency
  module CanonicalJson
    module_function

    def dump(value)
      JSON.generate(normalize(value))
    end

    def hash(value)
      Digest::SHA256.hexdigest(dump(value))
    end

    def normalize(value)
      case value
      when Hash
        value.keys.sort_by(&:to_s).each_with_object({}) do |key, memo|
          memo[key.to_s] = normalize(value[key])
        end
      when Array
        value.map { |item| normalize(item) }
      when Symbol
        value.to_s
      when Time, ActiveSupport::TimeWithZone
        value.utc.iso8601(6)
      when Date
        value.iso8601
      when BigDecimal
        value.to_s("F")
      else
        value
      end
    end
  end
end
