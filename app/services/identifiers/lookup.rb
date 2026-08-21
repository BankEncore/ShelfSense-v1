# frozen_string_literal: true

module Identifiers
  # Identity matching only. Callers apply their own eligibility rules (POS sellability,
  # return eligibility, adjustability); this service must never embed them.
  class Lookup
    Result = Struct.new(
      :status,
      :product,
      :products,
      :variant,
      :variants,
      :inventory_unit,
      :message,
      keyword_init: true
    )

    def self.call(raw)
      new(raw).call
    end

    def initialize(raw)
      @raw = raw
    end

    def call
      return invalid("identifier is blank") if @raw.to_s.strip.blank?

      row = registry_row
      return resolve_registry(row) if row

      resolve_lookup_code
    end

    private

    def registry_row
      normalized = Normalizer.normalize(@raw, allow_shelfsense_222: true)
      @normalization_error = nil
      Registry.find_any(normalized)
    rescue NormalizationError => e
      # Letter-containing and malformed values may still be lookup codes.
      @normalization_error = e.message
      nil
    end

    def resolve_registry(row)
      return Result.new(status: :retired, message: "Identifier is retired") if row.retired_at.present?

      case row.identifier_kind
      when "variant_sku", "variant_industry"
        variant = row.product_variant
        return Result.new(status: :not_found, message: "Variant missing") if variant.nil?

        Result.new(status: :variant, variant: variant, product: variant.product)
      when "product_primary", "product_industry"
        product = row.product
        return Result.new(status: :not_found, message: "Product missing") if product.nil?

        product_result(product)
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
        invalid("Unknown identifier kind")
      end
    end

    def resolve_lookup_code
      canonical = Product.canonical_lookup_code(@raw)
      return invalid(@normalization_error || "identifier cannot be interpreted") unless valid_lookup_code?(canonical)

      products = Product.where(lookup_code: canonical).order(:name, :primary_identifier).to_a
      case products.length
      when 0
        Result.new(status: :not_found, message: @normalization_error || "No match")
      when 1
        product_result(products.first)
      else
        Result.new(status: :multiple_products, products: products)
      end
    end

    def valid_lookup_code?(canonical)
      canonical.present? &&
        canonical.length <= Product::LOOKUP_CODE_MAX_LENGTH &&
        canonical.match?(Product::LOOKUP_CODE_FORMAT)
    end

    # Variants are returned unfiltered: eligibility belongs to the caller.
    def product_result(product)
      Result.new(status: :product, product: product, variants: product.product_variants.to_a)
    end

    def invalid(message)
      Result.new(status: :invalid, message: message)
    end
  end
end
