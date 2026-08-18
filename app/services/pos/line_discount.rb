# frozen_string_literal: true

module Pos
  module LineDiscount
    module_function

    def amount_cents(selling_unit_price_cents:, quantity:, basis_points:)
      basis = selling_unit_price_cents.to_i * quantity.to_i
      (BigDecimal(basis.to_s) * BigDecimal(basis_points.to_s) / 10_000).round(0, half: :up).to_i
    end
  end
end
