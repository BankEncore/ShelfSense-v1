# frozen_string_literal: true

module GiftCards
  class Lookup
    def self.by_number(raw)
      normalized = Number.normalize(raw)
      return if normalized.blank?
      return unless normalized.match?(/\A\d+\z/)

      GiftCard.find_by(number_digest: Number.digest(normalized))
    end

    def self.program_for(raw)
      normalized = Number.normalize(raw)
      return if normalized.blank?

      GiftCardProgram.active.find { |program| Number.shape_match?(normalized, program: program) }
    end
  end
end
