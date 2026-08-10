# frozen_string_literal: true

module Identifiers
  module Normalizer
    module_function

    def normalize(raw, allow_shelfsense_222: false)
      cleaned = raw.to_s.gsub(/[\s-]/, "")
      raise NormalizationError, "identifier is blank" if cleaned.blank?

      if cleaned.match?(/\A\d{10}\z/) || cleaned.match?(/\A\d{9}[\dXx]\z/)
        cleaned = isbn10_to_isbn13(cleaned)
      elsif cleaned.match?(/\A\d{12}\z/)
        cleaned = "0#{cleaned}"
      end

      raise NormalizationError, "identifier must be 13 digits" unless cleaned.match?(/\A\d{13}\z/)
      raise NormalizationError, "invalid check digit" unless Ean13.valid?(cleaned)

      if cleaned.start_with?("222") && !allow_shelfsense_222
        raise NormalizationError, "entered identifiers may not use the reserved 222 namespace"
      end

      cleaned
    end

    def isbn10_to_isbn13(isbn10)
      body = isbn10.to_s.upcase
      raise NormalizationError, "invalid ISBN-10" unless body.match?(/\A\d{9}[\dX]\z/)

      core = "978#{body[0, 9]}"
      "#{core}#{Ean13.check_digit(core)}"
    end
  end
end
