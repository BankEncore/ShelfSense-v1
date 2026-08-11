# frozen_string_literal: true

module Identifiers
  module Ean13
    module_function

    def check_digit(twelve_digits)
      digits = twelve_digits.to_s.chars.map(&:to_i)
      raise ArgumentError, "EAN-13 body must be 12 digits" unless digits.length == 12

      sum = digits.each_with_index.sum { |d, i| d * (i.even? ? 1 : 3) }
      (10 - (sum % 10)) % 10
    end

    def valid?(value)
      return false unless value.to_s.match?(/\A\d{13}\z/)

      body = value.to_s[0, 12]
      value.to_s[-1].to_i == check_digit(body)
    end

    def complete(prefix3, payload9)
      body = "#{prefix3}#{payload9}"
      raise ArgumentError, "body must be 12 digits" unless body.match?(/\A\d{12}\z/)

      "#{body}#{check_digit(body)}"
    end
  end
end
