# frozen_string_literal: true

module ProductVariants
  class Create
    class Error < StandardError; end

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(product:, attributes:, actor:, source: "ui")
      @product = product
      @attributes = attributes.to_h.symbolize_keys
      @actor = actor
      @source = source
    end

    def call
      variant_type = @attributes[:variant_type].to_s
      raise Error, "variant_type must be standard or used" unless ProductVariant::VARIANT_TYPES.include?(variant_type)

      condition_id = @attributes[:merchandise_condition_id].presence
      if variant_type == "used"
        raise Error, "merchandise_condition_id is required for used variants" if condition_id.blank?
      elsif condition_id.present?
        raise Error, "merchandise_condition_id must be blank for standard variants"
      end

      ProductVariant.transaction do
        condition = condition_id.present? ? MerchandiseCondition.find(condition_id) : nil
        klass = find_optional(MerchandiseClass, @attributes[:merchandise_class_id])
        validate_class_for_type!(variant_type, klass) if klass

        resolved = DefaultResolver.resolve(
          product: @product,
          variant_type: variant_type,
          condition: condition,
          merchandise_class: klass,
          department: find_optional(Department, @attributes[:department_id]),
          tax_class: find_optional(TaxClass, @attributes[:tax_class_id]),
          regular_price_cents: @attributes[:regular_price_cents]
        )
        validate_class_for_type!(variant_type, resolved.merchandise_class) if resolved.merchandise_class

        sku = allocate_221!
        industry = @attributes[:industry_identifier].presence
        normalized_industry =
          if industry
            Identifiers::Normalizer.normalize(industry, allow_shelfsense_222: false)
          end
        raise Error, "industry identifier cannot equal SKU" if normalized_industry.present? && normalized_industry == sku

        variant = @product.product_variants.new(
          @attributes.except(:industry_identifier, :sku).merge(
            variant_type: variant_type,
            sku: sku,
            industry_identifier: normalized_industry,
            merchandise_condition: condition,
            merchandise_class: resolved.merchandise_class,
            department: resolved.department,
            tax_class: resolved.tax_class,
            regular_price_cents: if @attributes.key?(:regular_price_cents)
                                   @attributes[:regular_price_cents]
                                 else
                                   resolved.suggested_price_cents
                                 end,
            status: @attributes[:status].presence || "draft"
          )
        )
        variant.identifier_writes_enabled = true
        variant.save!

        Identifiers::Registry.reserve!(value: sku, kind: "variant_sku", product_variant: variant)

        if normalized_industry.present?
          Identifiers::Registry.reserve!(value: normalized_industry, kind: "variant_industry", product_variant: variant)
        end

        Audit::Recorder.record!(
          action: "product_variants.create",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          subject: variant,
          after_values: {
            sku: variant.sku,
            product_id: variant.product_id,
            variant_type: variant.variant_type,
            source: @source
          }
        )

        variant
      end
    rescue Identifiers::NormalizationError, Identifiers::Registry::ConflictError, Identifiers::Generator::ExhaustedError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      raise Error, e.message
    end

    private

    def validate_class_for_type!(variant_type, klass)
      return if klass.blank?

      if variant_type == "used"
        raise Error, "used variants cannot use a non-inventory merchandise class" if klass.non_inventory?
        raise Error, "used variants require a merchandise class that allows used merchandise" unless klass.used_merchandise_allowed?
      end
    end

    def find_optional(model, id)
      return if id.blank?

      model.find(id)
    end

    def allocate_221!
      attempts = 0
      begin
        attempts += 1
        value = Identifiers::Generator.next_ean13!("221")
        return value unless Identifiers::Registry.find_any(value) || ProductVariant.exists?(sku: value)

        raise Identifiers::Registry::ConflictError, "generated SKU collision" if attempts < 5

        raise Identifiers::Registry::ConflictError, "unable to allocate unique 221 SKU"
      rescue Identifiers::Registry::ConflictError
        retry if attempts < 5
        raise
      end
    end
  end
end
