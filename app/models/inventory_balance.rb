# frozen_string_literal: true

class InventoryBalance < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :store
  belongs_to :product_variant

  validates :on_hand_quantity, :inventory_value_cents, presence: true

  def derived_average_unit_cost
    return if on_hand_quantity.to_i <= 0

    BigDecimal(inventory_value_cents.to_s) / on_hand_quantity
  end
end
