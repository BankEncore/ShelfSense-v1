# frozen_string_literal: true

class InventoryBalance < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :store
  belongs_to :product_variant

  validates :on_hand_quantity, :inventory_value_cents, presence: true
  validates :on_hand_quantity, :inventory_value_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def derived_average_unit_cost
    return if on_hand_quantity.to_i <= 0

    BigDecimal(inventory_value_cents.to_s) / on_hand_quantity
  end
end
