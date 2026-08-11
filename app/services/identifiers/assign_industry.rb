# frozen_string_literal: true

module Identifiers
  class AssignIndustry
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(variant:, raw_value:, actor: nil, source: "ui")
      @variant = variant
      @raw_value = raw_value
      @actor = actor
      @source = source
    end

    def call
      ProductVariant.transaction do
        previous = @variant.industry_identifier

        if @raw_value.blank?
          clear!(previous)
        else
          normalized = Normalizer.normalize(@raw_value, allow_shelfsense_222: false)
          raise Error, "industry identifier cannot equal SKU" if normalized == @variant.sku
          if normalized == previous
            @variant
          else
            # Retire first so the active variant_industry unique owner index allows the new row.
            Registry.retire!(value: previous) if previous.present?
            Registry.reserve!(value: normalized, kind: "variant_industry", product_variant: @variant)
            @variant.update!(industry_identifier: normalized)
            @variant
          end
        end
      end
    rescue NormalizationError, Registry::ConflictError, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def clear!(previous)
      return @variant if previous.blank?

      Registry.retire!(value: previous)
      @variant.update!(industry_identifier: nil)
      @variant
    end
  end
end
