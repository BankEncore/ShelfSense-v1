# frozen_string_literal: true

module Inventory
  module Costing
    module_function

    def round_half_up(value)
      BigDecimal(value.to_s).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    def value_removed_cents(current_value_cents:, current_quantity:, removal_magnitude:)
      raise ArgumentError, "removal magnitude must be positive" if removal_magnitude <= 0
      raise ArgumentError, "current quantity must be positive" if current_quantity <= 0

      return current_value_cents if removal_magnitude >= current_quantity

      round_half_up(
        BigDecimal(current_value_cents.to_s) * removal_magnitude / current_quantity
      )
    end
  end
end
