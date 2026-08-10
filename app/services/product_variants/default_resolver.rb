# frozen_string_literal: true

module ProductVariants
  class DefaultResolver
    Result = Struct.new(:merchandise_class, :department, :tax_class, :suggested_price_cents, keyword_init: true)

    def self.resolve(**attrs)
      new(**attrs).resolve
    end

    def initialize(product:, condition:, merchandise_class: nil, department: nil, tax_class: nil, regular_price_cents: nil)
      @product = product
      @condition = condition
      @merchandise_class = merchandise_class
      @department = department
      @tax_class = tax_class
      @regular_price_cents = regular_price_cents
    end

    def resolve
      klass = @merchandise_class || @product.merchandise_category&.default_merchandise_class
      department = @department || department_from(klass)
      tax = @tax_class || department&.default_tax_class
      price = @regular_price_cents
      if price.nil? && @product.list_price_cents.present? && @condition
        price = (@product.list_price_cents * @condition.price_adjustment_bps / 10_000.0).round
      end

      Result.new(
        merchandise_class: klass,
        department: department,
        tax_class: tax,
        suggested_price_cents: price
      )
    end

    private

    def department_from(klass)
      return if klass.blank?

      if @condition&.used_basis?
        klass.default_used_department
      else
        klass.default_standard_department
      end
    end
  end
end
