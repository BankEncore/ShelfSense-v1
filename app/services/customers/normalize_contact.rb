# frozen_string_literal: true

module Customers
  # Email and phone normalization for lookup and duplicate matching.
  #
  # Phone policy (Phase 8): E.164. US numbers without a country code are assumed +1.
  # Unparseable phones leave phone_normalized blank; display phone may still be stored.
  class NormalizeContact
    US_COUNTRY_CODE = "1"

    def self.email(value)
      normalized = value.to_s.strip.downcase
      normalized.presence
    end

    def self.phone(value)
      raw = value.to_s.strip
      return nil if raw.blank?

      digits = raw.gsub(/\D/, "")
      return nil if digits.blank?

      if raw.start_with?("+")
        return "+#{digits}" if digits.length.between?(8, 15)
        return nil
      end

      if digits.length == 10
        "+#{US_COUNTRY_CODE}#{digits}"
      elsif digits.length == 11 && digits.start_with?(US_COUNTRY_CODE)
        "+#{digits}"
      elsif digits.length.between?(8, 15)
        "+#{digits}"
      end
    end

    def self.apply!(customer)
      customer.email_normalized = email(customer.email) if customer.respond_to?(:email_normalized=)
      customer.phone_normalized = phone(customer.phone) if customer.respond_to?(:phone_normalized=)
    end
  end
end
