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
      @preexisting_product_ids = Product.pluck(:id).to_set

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
            group[:rows].each do |entry|
              product, product_status = upsert_product!(entry[:row])
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

    # Group only by unique product identity (primary or industry GTIN). Lookup codes are
    # intentionally nonunique, so they must never merge rows into one product group.
    # Rows with only a lookup code (or no identity) each get their own create/update group.
    def group_rows(rows)
      indexed = rows.each_with_index.map { |row, index| { row: row, line: index + 2 } }
      groups = []
      by_key = {}

      indexed.each do |entry|
        begin
          key = product_group_key(entry[:row], entry[:line])
        rescue Identifiers::NormalizationError => e
          groups << { rows: [ entry ], error: e.message }
          next
        end

        (by_key[key] ||= []) << entry
      end

      by_key.each_value { |entries| groups << { rows: entries } }
      groups
    end

    def product_group_key(row, line)
      if (raw = row["product_primary_identifier"].presence)
        return "primary:#{Identifiers::Normalizer.normalize(raw, allow_shelfsense_222: true)}"
      end

      if (raw = row["product_industry_identifier"].presence)
        return "industry:#{Identifiers::Normalizer.normalize(raw, allow_shelfsense_222: false)}"
      end

      "row:#{line}"
    end

    def variant_requested?(row)
      row["variant_type"].present? || row["variant_condition_code"].present? || row["sku"].present? || row["industry_identifier"].present?
    end

    def upsert_product!(row)
      product = locate_product!(row)
      if product
        Products::Update.call(
          product: product,
          actor: @actor,
          source: @source,
          attributes: product_update_attributes(row)
        )
        return [ product, :updated ]
      end

      created = Products::Create.call(
        attributes: { name: row.fetch("name"), status: row["status"].presence || "active" },
        actor: @actor,
        industry_identifier: row["product_industry_identifier"].presence,
        lookup_code: row["product_lookup_code"].presence,
        source: @source
      )
      [ created, :created ]
    end

    def locate_product!(row)
      if (raw = row["product_primary_identifier"].presence)
        normalized = Identifiers::Normalizer.normalize(raw, allow_shelfsense_222: true)
        product = Product.find_by(primary_identifier: normalized)
        raise Error, "unknown product_primary_identifier #{normalized}; ShelfSense generates primary identifiers" if product.nil?

        return product
      end

      if (raw = row["product_industry_identifier"].presence)
        normalized = Identifiers::Normalizer.normalize(raw, allow_shelfsense_222: false)
        matches = Product.where(industry_identifier: normalized).to_a
        raise Error, "product_industry_identifier #{normalized} is ambiguous" if matches.many?

        return matches.first
      end

      code = Product.canonical_lookup_code(row["product_lookup_code"])
      return nil if code.blank?

      matches = Product.where(lookup_code: code).select { |product| @preexisting_product_ids.include?(product.id) }
      if matches.many?
        raise Error, "product_lookup_code #{code} matches #{matches.size} products; use product_primary_identifier"
      end

      matches.first
    end

    # A blank cell never clears identity. Retiring a product GTIN or dropping a lookup
    # code is an explicit admin action, not a side effect of a mostly empty template row.
    def product_update_attributes(row)
      attrs = {}
      attrs[:name] = row["name"] if row["name"].present?
      attrs[:status] = row["status"] if row["status"].present?
      attrs[:lookup_code] = row["product_lookup_code"] if row["product_lookup_code"].present?
      attrs[:industry_identifier] = row["product_industry_identifier"] if row["product_industry_identifier"].present?
      attrs
    end

    def upsert_variant!(product, row)
      if row["sku"].present?
        variant = ProductVariant.find_by(sku: row["sku"])
        raise Error, "caller-assigned SKU is not accepted for new variants; SKU not found for update" unless variant
        raise Error, "SKU belongs to a different product" unless variant.product_id == product.id

        return [ variant, :updated ]
      end

      if row["industry_identifier"].present?
        normalized = Identifiers::Normalizer.normalize(row["industry_identifier"], allow_shelfsense_222: false)
        matches = ProductVariant.where(industry_identifier: normalized).to_a
        raise Error, "industry identifier #{normalized} is ambiguous" if matches.many?

        if (variant = matches.first)
          raise Error, "industry identifier belongs to a different product" unless variant.product_id == product.id

          return [ variant, :updated ]
        end
      end

      variant_type = row["variant_type"].to_s.presence
      raise Error, "insufficient identity to create or update variant" if variant_type.blank?

      variant = ProductVariants::Create.call(
        product: product,
        actor: @actor,
        source: @source,
        attributes: variant_create_attributes!(row, variant_type)
      )
      [ variant, :created ]
    end

    def variant_create_attributes!(row, variant_type)
      attributes = {
        variant_type: variant_type,
        industry_identifier: row["industry_identifier"],
        regular_price_cents: row["regular_price_cents"].presence&.to_i,
        status: row["status"].presence || "active"
      }
      attributes.merge!(resolve_reference_ids!(row))
      attributes.merge!(resolve_operational_values!(row))

      if variant_type == "used"
        raise Error, "variant_condition_code is required for used variants" if row["variant_condition_code"].blank?

        condition = MerchandiseCondition.find_by(code: row["variant_condition_code"])
        raise Error, "unknown variant_condition_code: #{row["variant_condition_code"]}" if condition.nil?

        attributes[:merchandise_condition_id] = condition.id
      elsif row["variant_condition_code"].present?
        raise Error, "variant_condition_code must be blank for standard variants"
      end

      attributes.compact
    end

    def resolve_reference_ids!(row)
      ids = {}
      code = row["merchandise_class_code"].presence
      if code
        klass = MerchandiseClass.find_by(code: code)
        raise Error, "unknown merchandise_class_code: #{code}" if klass.nil?

        ids[:merchandise_class_id] = klass.id
      end

      # Blank means inherit the merchandise class default; only an explicit code overrides.
      code = row["tax_class_override_code"].presence
      if code
        tax = TaxClass.find_by(code: code)
        raise Error, "unknown tax_class_override_code: #{code}" if tax.nil?

        ids[:tax_class_override_id] = tax.id
      end

      ids
    end

    # Omitted columns keep the merchandise-class default; explicit values (including
    # `false` supplier returnability) win.
    def resolve_operational_values!(row)
      values = {}
      values[:inventory_mode] = row["inventory_mode"] if row["inventory_mode"].present?
      values[:pricing_method] = row["pricing_method"] if row["pricing_method"].present?

      if row["target_margin_bps"].present?
        values[:target_margin_bps] = Integer(row["target_margin_bps"], exception: false) ||
                                     raise(Error, "target_margin_bps must be an integer")
      end

      if row["supplier_returnable"].present?
        case row["supplier_returnable"].to_s.strip.downcase
        when "true", "t", "yes", "y", "1" then values[:supplier_returnable] = true
        when "false", "f", "no", "n", "0" then values[:supplier_returnable] = false
        else raise Error, "supplier_returnable must be true or false"
        end
      end

      values
    end
  end
end
