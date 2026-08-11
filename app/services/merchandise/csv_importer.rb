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

      groups = group_rows(CSV.parse(@io.read, headers: true))
      groups.each do |group|
        if group[:error]
          errors << { row: group[:rows].map { |e| e[:line] }.join(","), message: group[:error] }
          next
        end

        begin
          product_statuses = []
          variant_statuses = []

          ActiveRecord::Base.transaction do
            product = nil
            group[:rows].each do |entry|
              product, product_status = upsert_product!(entry[:row], generate_only: group[:generate_only])
              product_statuses << product_status
              next unless variant_requested?(entry[:row])

              _, variant_status = upsert_variant!(product, entry[:row])
              variant_statuses << variant_status
            end
          end

          created_products += 1 if product_statuses.include?(:created)
          updated_products += 1 if product_statuses.include?(:updated) && !product_statuses.include?(:created)
          created_variants += variant_statuses.count(:created)
          updated_variants += variant_statuses.count(:updated)
        rescue StandardError => e
          errors << { row: group[:rows].map { |e| e[:line] }.join(","), message: e.message }
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

    def group_rows(rows)
      indexed = rows.each_with_index.map { |row, index| { row: row, line: index + 2 } }
      groups = []
      by_primary = Hash.new { |h, k| h[k] = [] }

      indexed.each do |entry|
        row = entry[:row]
        generate = ActiveModel::Type::Boolean.new.cast(row["generate_primary_identifier"])
        raw_id = row["primary_identifier"].presence

        if raw_id.blank? && generate
          groups << { generate_only: true, rows: [ entry ] }
          next
        end

        if raw_id.blank?
          groups << { generate_only: false, rows: [ entry ], error: "primary_identifier is required or generate_primary_identifier must be true" }
          next
        end

        begin
          key = Identifiers::Normalizer.normalize(raw_id, allow_shelfsense_222: true)
          by_primary[key] << entry
        rescue Identifiers::NormalizationError => e
          groups << { generate_only: false, rows: [ entry ], error: e.message }
        end
      end

      by_primary.each_value { |entries| groups << { generate_only: false, rows: entries } }
      groups
    end

    def variant_requested?(row)
      row["variant_type"].present? || row["variant_condition_code"].present? || row["sku"].present? || row["industry_identifier"].present?
    end

    def upsert_product!(row, generate_only:)
      if generate_only
        product = Products::Create.call(
          attributes: { name: row.fetch("name"), status: row["status"].presence || "draft" },
          actor: @actor,
          identifier_mode: "generate",
          source: @source
        )
        return [ product, :created ]
      end

      raw_id = row["primary_identifier"].presence
      raise Error, "primary_identifier is required or generate_primary_identifier must be true" if raw_id.blank?

      normalized = Identifiers::Normalizer.normalize(raw_id, allow_shelfsense_222: true)
      if (existing = Product.find_by(primary_identifier: normalized))
        Products::Update.call(
          product: existing,
          actor: @actor,
          source: @source,
          attributes: { name: row["name"].presence || existing.name }
        )
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
    end

    def upsert_variant!(product, row)
      if row["sku"].present?
        variant = ProductVariant.find_by(sku: row["sku"])
        raise Error, "caller-assigned SKU is not accepted for new variants; SKU not found for update" unless variant
        raise Error, "SKU belongs to a different product" unless variant.product_id == product.id

        ProductVariants::Update.call(
          variant: variant,
          actor: @actor,
          source: @source,
          attributes: { name: row["variant_name"].presence || variant.name }
        )
        return [ variant, :updated ]
      end

      if row["industry_identifier"].present?
        normalized = Identifiers::Normalizer.normalize(row["industry_identifier"], allow_shelfsense_222: false)
        if (variant = ProductVariant.find_by(industry_identifier: normalized))
          raise Error, "industry identifier belongs to a different product" unless variant.product_id == product.id

          if row["variant_name"].present?
            ProductVariants::Update.call(
              variant: variant,
              actor: @actor,
              source: @source,
              attributes: { name: row["variant_name"] }
            )
          end
          return [ variant, :updated ]
        end
      end

      variant_type = row["variant_type"].to_s.presence
      raise Error, "insufficient identity to create or update variant" if variant_type.blank?

      attributes = {
        variant_type: variant_type,
        name: row["variant_name"],
        industry_identifier: row["industry_identifier"],
        regular_price_cents: row["regular_price_cents"].presence&.to_i
      }
      attributes.merge!(resolve_reference_ids!(row))

      if variant_type == "used"
        raise Error, "variant_condition_code is required for used variants" if row["variant_condition_code"].blank?

        condition = MerchandiseCondition.find_by(code: row["variant_condition_code"])
        raise Error, "unknown variant_condition_code: #{row["variant_condition_code"]}" if condition.nil?

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

    def resolve_reference_ids!(row)
      ids = {}
      code = row["merchandise_class_code"].presence
      if code
        klass = MerchandiseClass.find_by(code: code)
        raise Error, "unknown merchandise_class_code: #{code}" if klass.nil?

        ids[:merchandise_class_id] = klass.id
      end

      code = row["department_code"].presence
      if code
        dept = Department.find_by(code: code)
        raise Error, "unknown department_code: #{code}" if dept.nil?

        ids[:department_id] = dept.id
      end

      code = row["tax_class_code"].presence
      if code
        tax = TaxClass.find_by(code: code)
        raise Error, "unknown tax_class_code: #{code}" if tax.nil?

        ids[:tax_class_id] = tax.id
      end

      ids
    end
  end
end
