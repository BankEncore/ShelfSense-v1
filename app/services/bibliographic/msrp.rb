# frozen_string_literal: true

require "bigdecimal"

module Bibliographic
  module Msrp
    module_function

    def to_cents(raw)
      return if raw.nil?

      text = raw.to_s.strip
      return if text.empty?

      normalized = text.delete("$").delete(",").delete(" ")
      return unless normalized.match?(/\A\d+(?:\.\d{1,4})?\z/)

      cents = (BigDecimal(normalized) * 100).round.to_i
      return if cents <= 0

      cents
    rescue ArgumentError
      nil
    end
  end
end
