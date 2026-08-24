# frozen_string_literal: true

module Customers
  # Suggests likely duplicate customers for create/edit review.
  #
  # Strong match: equality on email_normalized or phone_normalized when present.
  # Weak match: ≥ WEAK_NAME_TOKEN_OVERLAP normalized display-name tokens in common.
  # Merged aliases are never returned as independent candidates.
  class SuggestDuplicates
    WEAK_NAME_TOKEN_OVERLAP = 2
    MAX_RESULTS = 10

    Suggestion = Data.define(:customer, :match_strength, :matched_on)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(attributes:, exclude_id: nil)
      @attributes = attributes.to_h.symbolize_keys
      @exclude_id = exclude_id
    end

    def call
      email_n = Customers::NormalizeContact.email(@attributes[:email])
      phone_n = Customers::NormalizeContact.phone(@attributes[:phone])
      tokens = name_tokens(search_display_name)

      candidates = {}

      if email_n.present?
        Customer.canonical.where(email_normalized: email_n).find_each do |customer|
          next if excluded?(customer)

          candidates[customer.id] = Suggestion.new(
            customer: customer,
            match_strength: :strong,
            matched_on: "email"
          )
        end
      end

      if phone_n.present?
        Customer.canonical.where(phone_normalized: phone_n).find_each do |customer|
          next if excluded?(customer)

          existing = candidates[customer.id]
          next if existing&.match_strength == :strong

          candidates[customer.id] = Suggestion.new(
            customer: customer,
            match_strength: :strong,
            matched_on: "phone"
          )
        end
      end

      if tokens.size >= WEAK_NAME_TOKEN_OVERLAP
        Customer.canonical.find_each do |customer|
          next if excluded?(customer)
          next if candidates.key?(customer.id)

          overlap = (name_tokens(customer.display_name) & tokens).size
          next if overlap < WEAK_NAME_TOKEN_OVERLAP

          candidates[customer.id] = Suggestion.new(
            customer: customer,
            match_strength: :weak,
            matched_on: "name"
          )
        end
      end

      candidates.values
        .sort_by { |s| [ s.match_strength == :strong ? 0 : 1, s.customer.display_name, s.customer.id ] }
        .first(MAX_RESULTS)
    end

    private

    def excluded?(customer)
      @exclude_id.present? && customer.id == @exclude_id
    end

    # Prefer an explicit display_name; otherwise derive Family, Given so weak
    # matching still runs when staff leave display_name blank.
    def search_display_name
      explicit = @attributes[:display_name].to_s.strip.presence
      return explicit if explicit

      Customer.derived_display_name(
        family_name: @attributes[:family_name],
        given_name: @attributes[:given_name]
      )
    end

    def name_tokens(value)
      value.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").split.reject { |t| t.length < 2 }.uniq
    end
  end
end
