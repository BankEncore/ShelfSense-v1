# frozen_string_literal: true

module Identifiers
  class AssignIndustry
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(variant:, raw_value:, actor: nil, source: "ui", persist: true)
      @variant = variant
      @raw_value = raw_value
      @actor = actor
      @source = source
      @persist = persist
    end

    def call
      ProductVariant.transaction do
        previous = @variant.industry_identifier

        if @raw_value.blank?
          apply_clear!(previous)
        else
          normalized = Normalizer.normalize(@raw_value, allow_shelfsense_222: false)
          raise Error, "industry identifier cannot equal SKU" if normalized == @variant.sku
          apply_replace!(previous, normalized) unless normalized == previous
        end

        if @persist
          @variant.identifier_writes_enabled = true
          @variant.save!
        end

        @variant
      end
    rescue NormalizationError, Registry::ConflictError, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def apply_clear!(previous)
      return if previous.blank?

      Registry.retire!(value: previous)
      @variant.identifier_writes_enabled = true
      @variant.industry_identifier = nil
    end

    def apply_replace!(previous, normalized)
      # Retire first so the active variant_industry unique owner index allows the new row.
      Registry.retire!(value: previous) if previous.present?
      Registry.reserve!(value: normalized, kind: "variant_industry", product_variant: @variant)
      @variant.identifier_writes_enabled = true
      @variant.industry_identifier = normalized
    end
  end
end
