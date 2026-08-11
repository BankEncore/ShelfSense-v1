# frozen_string_literal: true

module Identifiers
  class Registry
    class ConflictError < StandardError; end

    def self.reserve!(value:, kind:, product: nil, product_variant: nil)
      new.reserve!(value: value, kind: kind, product: product, product_variant: product_variant)
    end

    def self.retire!(value:)
      new.retire!(value: value)
    end

    def self.find_active(value)
      IdentifierRegistry.find_by(value: value, retired_at: nil)
    end

    def self.find_any(value)
      IdentifierRegistry.find_by(value: value)
    end

    def reserve!(value:, kind:, product: nil, product_variant: nil)
      if IdentifierRegistry.exists?(value: value)
        raise ConflictError, "identifier #{value} is already reserved"
      end

      IdentifierRegistry.create!(
        value: value,
        identifier_kind: kind,
        product: product,
        product_variant: product_variant,
        retired_at: nil
      )
    rescue ActiveRecord::RecordNotUnique
      raise ConflictError, "identifier #{value} is already reserved"
    end

    def retire!(value:)
      row = IdentifierRegistry.find_by!(value: value)
      row.update!(retired_at: Time.current)
      row
    end
  end
end
