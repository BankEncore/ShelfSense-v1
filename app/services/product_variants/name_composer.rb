# frozen_string_literal: true

module ProductVariants
  # Shared composition for persisted variant.name and receipt variant_detail.
  module NameComposer
    module_function

    def normalize_option_value(raw)
      text = raw.to_s.strip.gsub(/\s+/, " ")
      return nil if text.blank?

      text.downcase
    end

    def normalize_label(raw)
      text = raw.to_s.strip.gsub(/\s+/, " ")
      return nil if text.blank?

      text.downcase
    end

    def trim_display(raw)
      text = raw.to_s.strip.gsub(/\s+/, " ")
      text.presence
    end

    # Persisted product_variants.name projection (PVA-006).
    def name(variant_type:, condition_name: nil, option_value_1: nil, option_value_2: nil, product: nil)
      v1 = trim_display(option_value_1)
      v2 = trim_display(option_value_2)
      attributed = product.nil? ? v1.present? || v2.present? : product_has_labels?(product)

      if variant_type.to_s == "used"
        cond = condition_name.to_s.strip.presence
        return cond if !attributed || (v1.blank? && v2.blank?)
        return "#{cond} · #{v1}" if v2.blank?

        "#{cond} · #{v1} / #{v2}"
      else
        return "Standard" if !attributed || (v1.blank? && v2.blank?)
        return v1 if v2.blank?

        "#{v1} / #{v2}"
      end
    end

    # Receipt / snapshot detail (PVA-008). Nil means omit the detail line.
    def detail(variant_type:, condition_name: nil, option_value_1: nil, option_value_2: nil, product: nil)
      composed = name(
        variant_type: variant_type,
        condition_name: condition_name,
        option_value_1: option_value_1,
        option_value_2: option_value_2,
        product: product
      )
      return nil if variant_type.to_s == "standard" && composed == "Standard"

      composed
    end

    def detail_for_variant(variant)
      detail(
        variant_type: variant.variant_type,
        condition_name: variant.merchandise_condition&.name,
        option_value_1: variant.option_value_1,
        option_value_2: variant.option_value_2,
        product: variant.product
      )
    end

    def name_for_variant(variant)
      name(
        variant_type: variant.variant_type,
        condition_name: variant.merchandise_condition&.name,
        option_value_1: variant.option_value_1,
        option_value_2: variant.option_value_2,
        product: variant.product
      )
    end

    def product_has_labels?(product)
      product.variant_option_name_1.to_s.strip.present?
    end
  end
end
