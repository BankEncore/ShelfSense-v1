# frozen_string_literal: true

module Identifiers
  class Lookup
    Result = Struct.new(:status, :product, :variant, :variants, :inventory_unit, :message, keyword_init: true)

    def self.call(raw)
      new(raw).call
    end

    def initialize(raw)
      @raw = raw
    end

    def call
      normalized = Normalizer.normalize(@raw, allow_shelfsense_222: true)
      row = Registry.find_any(normalized)
      return Result.new(status: :not_found, message: "No match") if row.nil?
      return Result.new(status: :retired, message: "Identifier is retired") if row.retired_at.present?

      case row.identifier_kind
      when "variant_sku", "variant_industry"
        variant = row.product_variant
        return Result.new(status: :not_found, message: "Variant missing") if variant.nil?

        Result.new(status: :variant, variant: variant, product: variant.product)
      when "product_primary"
        product = row.product
        return Result.new(status: :not_found, message: "Product missing") if product.nil?

        eligible = product.product_variants.select(&:sellable?)
        if eligible.one?
          Result.new(status: :variant, variant: eligible.first, product: product)
        elsif eligible.many?
          Result.new(status: :multi_variant, product: product, variants: eligible)
        else
          Result.new(status: :product, product: product)
        end
      when "inventory_unit"
        unit = row.inventory_unit
        return Result.new(status: :not_found, message: "Unit missing") if unit.nil?

        variant = unit.product_variant
        Result.new(
          status: :inventory_unit,
          inventory_unit: unit,
          variant: variant,
          product: variant&.product
        )
      else
        Result.new(status: :invalid, message: "Unknown identifier kind")
      end
    rescue NormalizationError => e
      Result.new(status: :invalid, message: e.message)
    end
  end
end
