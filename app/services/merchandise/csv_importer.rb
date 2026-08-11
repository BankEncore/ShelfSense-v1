# frozen_string_literal: true

require "csv"

module Merchandise
  class CsvImporter
    class Error < StandardError; end
    Result = Struct.new(:created_products, :updated_products, :created_variants, :updated_variants, :errors, keyword_init: true)

    def self.call(io:, actor:, source: "csv_import")
      new(io: io, actor: actor, source: source).call
    end

    def initialize(io:, actor:, source:)
      @io = io
      @actor = actor
      @source = source
    end

    def call
      created_products = 0
      updated_products = 0
      created_variants = 0
      updated_variants = 0
      errors = []

      rows = CSV.parse(@io.read, headers: true)
      rows.each_with_index do |row, index|
        begin
          ActiveRecord::Base.transaction do
            product, product_status = upsert_product!(row)
            created_products += 1 if product_status == :created
            updated_products += 1 if product_status == :updated

            if row["variant_type"].present? || row["variant_condition_code"].present? || row["sku"].present? || row["industry_identifier"].present?
              _, variant_status = upsert_variant!(product, row)
              created_variants += 1 if variant_status == :created
              updated_variants += 1 if variant_status == :updated
            end
          end
        rescue StandardError => e
          errors << { row: index + 2, message: e.message }
        end
      end

      Result.new(
        created_products: created_products,
        updated_products: updated_products,
        created_variants: created_variants,
        updated_variants: updated_variants,
        errors: errors
      )
    end

    private

    def upsert_product!(row)
      generate = ActiveModel::Type::Boolean.new.cast(row["generate_primary_identifier"])
      raw_id = row["primary_identifier"].presence

      if raw_id.blank? && !generate
        raise Error, "primary_identifier is required or generate_primary_identifier must be true"
      end

      if raw_id.present?
        normalized = Identifiers::Normalizer.normalize(raw_id, allow_shelfsense_222: true)
        if (existing = Product.find_by(primary_identifier: normalized))
          existing.update!(name: row["name"].presence || existing.name)
          return [ existing, :updated ]
        end

        product = Products::Create.call(
          attributes: { name: row.fetch("name"), status: row["status"].presence || "draft" },
          actor: @actor,
          identifier_mode: "enter",
          external_identifier: raw_id,
          source: @source
        )
        [ product, :created ]
      else
        product = Products::Create.call(
          attributes: { name: row.fetch("name"), status: row["status"].presence || "draft" },
          actor: @actor,
          identifier_mode: "generate",
          source: @source
        )
        [ product, :created ]
      end
    end

    def upsert_variant!(product, row)
      if row["sku"].present?
        variant = ProductVariant.find_by(sku: row["sku"])
        raise Error, "caller-assigned SKU is not accepted for new variants; SKU not found for update" unless variant
        raise Error, "SKU belongs to a different product" unless variant.product_id == product.id

        variant.update!(name: row["variant_name"].presence || variant.name)
        return [ variant, :updated ]
      end

      if row["industry_identifier"].present?
        normalized = Identifiers::Normalizer.normalize(row["industry_identifier"], allow_shelfsense_222: false)
        if (variant = ProductVariant.find_by(industry_identifier: normalized))
          raise Error, "industry identifier belongs to a different product" unless variant.product_id == product.id

          variant.update!(name: row["variant_name"].presence || variant.name) if row["variant_name"].present?
          return [ variant, :updated ]
        end
      end

      variant_type = row["variant_type"].to_s.presence
      raise Error, "insufficient identity to create or update variant" if variant_type.blank?

      attributes = {
        variant_type: variant_type,
        name: row["variant_name"],
        industry_identifier: row["industry_identifier"],
        regular_price_cents: row["regular_price_cents"].presence&.to_i,
        merchandise_class_id: MerchandiseClass.find_by(code: row["merchandise_class_code"])&.id,
        department_id: Department.find_by(code: row["department_code"])&.id,
        tax_class_id: TaxClass.find_by(code: row["tax_class_code"])&.id
      }

      if variant_type == "used"
        raise Error, "variant_condition_code is required for used variants" if row["variant_condition_code"].blank?

        condition = MerchandiseCondition.find_by!(code: row["variant_condition_code"])
        attributes[:merchandise_condition_id] = condition.id
      elsif row["variant_condition_code"].present?
        raise Error, "variant_condition_code must be blank for standard variants"
      end

      variant = ProductVariants::Create.call(
        product: product,
        actor: @actor,
        source: @source,
        attributes: attributes.compact
      )
      [ variant, :created ]
    end
  end
end
