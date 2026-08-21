# frozen_string_literal: true

module ProductVariants
  class DefaultResolver
    Result = Struct.new(
      :merchandise_class,
      :inventory_mode,
      :pricing_method,
      :target_margin_bps,
      :supplier_returnable,
      :tax_class_override,
      :suggested_price_cents,
      keyword_init: true
    )

    def self.resolve(**attrs)
      new(**attrs).resolve
    end

    def initialize(
      product:,
      variant_type:,
      condition: nil,
      merchandise_class: nil,
      inventory_mode: nil,
      pricing_method: nil,
      target_margin_bps: :omitted,
      supplier_returnable: :omitted,
      tax_class_override: :omitted,
      regular_price_cents: nil
    )
      @product = product
      @variant_type = variant_type.to_s
      @condition = condition
      @merchandise_class = merchandise_class
      @inventory_mode = inventory_mode
      @pricing_method = pricing_method
      @target_margin_bps = target_margin_bps
      @supplier_returnable = supplier_returnable
      @tax_class_override = tax_class_override
      @regular_price_cents = regular_price_cents
    end

    def resolve
      klass = @merchandise_class || category_default_class
      inventory_mode = @inventory_mode.presence || klass&.default_inventory_mode
      pricing_method = @pricing_method.presence || klass&.default_pricing_method
      target_margin_bps =
        if @target_margin_bps == :omitted
          klass&.target_margin_bps
        else
          @target_margin_bps
        end
      supplier_returnable =
        if @supplier_returnable == :omitted
          klass.nil? ? nil : klass.default_supplier_returnable
        else
          @supplier_returnable
        end
      tax_override =
        if @tax_class_override == :omitted
          nil
        else
          @tax_class_override
        end

      price = @regular_price_cents
      price = suggested_price_for(klass, pricing_method) if price.nil?

      Result.new(
        merchandise_class: klass,
        inventory_mode: inventory_mode,
        pricing_method: pricing_method,
        target_margin_bps: target_margin_bps,
        supplier_returnable: supplier_returnable,
        tax_class_override: tax_override,
        suggested_price_cents: price
      )
    end

    private

    def category_default_class
      category = @product.merchandise_category
      return if category.blank?

      if @variant_type == "used"
        category.default_used_merchandise_class
      else
        category.default_standard_merchandise_class
      end
    end

    def suggested_price_for(klass, pricing_method)
      return if klass.blank?
      return unless pricing_method == "list_price"
      return if @product.list_price_cents.blank?

      if @variant_type == "used" && @condition
        (@product.list_price_cents * @condition.price_adjustment_bps + 5_000) / 10_000
      else
        @product.list_price_cents
      end
    end
  end
end
