# frozen_string_literal: true

module GiftCards
  module Number
    module_function

    PHASE10_LENGTH = 20

    def normalize(raw)
      raw.to_s.gsub(/[\s-]/, "")
    end

    def digest(normalized)
      key = Rails.application.config.x.gift_card_number_hmac_key
      raise GiftCards::Error, "gift-card HMAC key is not configured" if key.blank?

      OpenSSL::HMAC.hexdigest("SHA256", key, normalized)
    end

    def last_four(normalized)
      normalized.to_s[-4, 4]
    end

    def generate(program)
      prefix = program.prefix
      length = program.number_length
      body_length = length - prefix.length - 1
      raise GiftCards::Error, "program prefix is too long for the number length" if body_length < 1

      25.times do
        body = format("%0#{body_length}d", SecureRandom.random_number(10**body_length))
        candidate = "#{prefix}#{body}#{Luhn.check_digit("#{prefix}#{body}")}"
        next if GiftCard.exists?(number_digest: digest(candidate))

        return candidate
      end
      raise GiftCards::Error, "unable to allocate a unique gift-card number"
    end

    def shape_match?(normalized, program:)
      normalized.match?(/\A\d+\z/) &&
        normalized.length == program.number_length &&
        normalized.start_with?(program.prefix) &&
        Luhn.valid?(normalized)
    end

    def matches_active_program?(raw)
      normalized = normalize(raw)
      return false unless normalized.match?(/\A\d+\z/)

      GiftCardProgram.active.find_each.any? { |program| shape_match?(normalized, program: program) }
    end
  end
end
