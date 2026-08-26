# frozen_string_literal: true

module GiftCards
  module Luhn
    module_function

    def check_digit(body)
      digits = body.to_s.chars.map(&:to_i)
      raise ArgumentError, "Luhn body must be digits" unless body.to_s.match?(/\A\d+\z/)

      sum = luhn_sum("#{body}0")
      (10 - (sum % 10)) % 10
    end

    def valid?(value)
      return false unless value.to_s.match?(/\A\d+\z/)
      return false if value.to_s.length < 2

      (luhn_sum(value) % 10).zero?
    end

    def luhn_sum(value)
      value.to_s.chars.map(&:to_i).reverse.each_with_index.sum do |digit, index|
        if index.odd?
          doubled = digit * 2
          doubled > 9 ? doubled - 9 : doubled
        else
          digit
        end
      end
    end
  end
end
