# frozen_string_literal: true

module Pos
  module Tax
    class UnresolvedApplicability < StandardError; end

    class Calculate
      Determination = Struct.new(
        :store_tax_id,
        :store_tax_code,
        :store_tax_name,
        :rate_percent,
        :applies,
        :taxable_basis_cents,
        :tax_cents,
        :calculation_order,
        keyword_init: true
      )

      Result = Struct.new(:determinations, :tax_cents, keyword_init: true)

      def self.call(**attrs)
        new(**attrs).call
      end

      def initialize(store:, tax_class:, taxable_basis_cents:)
        @store = store
        @tax_class = tax_class
        @taxable_basis_cents = taxable_basis_cents.to_i
      end

      def call
        determinations = StoreTax.active.where(store: @store).calculation_ordered.map do |store_tax|
          rule = store_tax.store_tax_rules.find_by(tax_class: @tax_class)
          if rule.nil? || rule.applies.nil?
            raise UnresolvedApplicability,
                  "Store tax #{store_tax.code} has no applicability decision for tax class #{@tax_class.code}"
          end

          if rule.applies
            tax_cents = half_up_tax(@taxable_basis_cents, store_tax.rate_percent)
            Determination.new(
              store_tax_id: store_tax.id,
              store_tax_code: store_tax.code,
              store_tax_name: store_tax.name,
              rate_percent: format("%.3f", store_tax.rate_percent),
              applies: true,
              taxable_basis_cents: @taxable_basis_cents,
              tax_cents: tax_cents,
              calculation_order: store_tax.calculation_order
            )
          else
            Determination.new(
              store_tax_id: store_tax.id,
              store_tax_code: store_tax.code,
              store_tax_name: store_tax.name,
              rate_percent: format("%.3f", store_tax.rate_percent),
              applies: false,
              taxable_basis_cents: 0,
              tax_cents: 0,
              calculation_order: store_tax.calculation_order
            )
          end
        end

        Result.new(determinations: determinations, tax_cents: determinations.sum(&:tax_cents))
      end

      private

      def half_up_tax(basis_cents, rate_percent)
        (BigDecimal(basis_cents.to_s) * BigDecimal(rate_percent.to_s) / 100).round(0, half: :up).to_i
      end
    end
  end
end
