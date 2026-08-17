# frozen_string_literal: true

module StoreTaxes
  class EnsureRules
    def self.for_store_tax(store_tax)
      new.for_store_tax(store_tax)
    end

    def self.for_tax_class(tax_class)
      new.for_tax_class(tax_class)
    end

    def for_store_tax(store_tax)
      TaxClass.assignable.find_each do |tax_class|
        ensure_rule!(store_tax: store_tax, tax_class: tax_class)
      end
    end

    def for_tax_class(tax_class)
      return unless tax_class.assignable?

      StoreTax.active.find_each do |store_tax|
        ensure_rule!(store_tax: store_tax, tax_class: tax_class)
      end
    end

    private

    def ensure_rule!(store_tax:, tax_class:)
      StoreTaxRule.find_or_create_by!(store_tax: store_tax, tax_class: tax_class) do |rule|
        rule.applies = nil
      end
    end
  end
end
