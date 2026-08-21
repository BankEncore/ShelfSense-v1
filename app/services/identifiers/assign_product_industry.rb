# frozen_string_literal: true

module Identifiers
  class AssignProductIndustry
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(product:, raw_value:, actor: nil, source: "ui", persist: true)
      @product = product
      @raw_value = raw_value
      @actor = actor
      @source = source
      @persist = persist
    end

    def call
      Product.transaction do
        previous = @product.industry_identifier

        if @raw_value.blank?
          apply_clear!(previous)
        else
          normalized = Normalizer.normalize(@raw_value, allow_shelfsense_222: false)
          raise Error, "industry identifier cannot equal the primary identifier" if normalized == @product.primary_identifier
          apply_replace!(previous, normalized) unless normalized == previous
        end

        if @persist
          @product.identifier_writes_enabled = true
          @product.save!
        end

        @product
      end
    rescue NormalizationError, Registry::ConflictError, ActiveRecord::RecordInvalid => e
      raise Error, e.message
    end

    private

    def apply_clear!(previous)
      return if previous.blank?

      Registry.retire!(value: previous)
      @product.identifier_writes_enabled = true
      @product.industry_identifier = nil
    end

    def apply_replace!(previous, normalized)
      # Retire first so the active product_industry unique owner index allows the new row.
      Registry.retire!(value: previous) if previous.present?
      Registry.reserve!(value: normalized, kind: "product_industry", product: @product)
      @product.identifier_writes_enabled = true
      @product.industry_identifier = normalized
    end
  end
end
