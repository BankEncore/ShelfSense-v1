# frozen_string_literal: true

module Money
  # Parses HTML admin currency strings into integer cents.
  # Import/API/CSV contracts continue to use integer cents directly.
  class ParseCents
    class Error < StandardError; end

    def self.call(raw)
      new(raw).call
    end

    def initialize(raw)
      @raw = raw
    end

    def call
      return nil if @raw.nil?

      text = @raw.to_s.strip
      return nil if text.empty?

      normalized = text.delete("$").delete(",").delete(" ")
      unless normalized.match?(/\A-?\d+(?:\.\d{1,2})?\z/)
        raise Error, "is not a valid amount"
      end

      (BigDecimal(normalized) * 100).round.to_i
    rescue ArgumentError
      raise Error, "is not a valid amount"
    end
  end
end
