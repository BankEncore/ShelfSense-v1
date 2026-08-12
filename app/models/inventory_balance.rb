# frozen_string_literal: true

class InventoryBalance < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :store
  belongs_to :product_variant

  validates :on_hand_quantity, :inventory_value_cents, presence: true
  validates :on_hand_quantity, :inventory_value_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :zero_quantity_implies_zero_value

  def derived_average_unit_cost
    return if on_hand_quantity.to_i <= 0

    BigDecimal(inventory_value_cents.to_s) / on_hand_quantity
  end

  private

  def zero_quantity_implies_zero_value
    return unless on_hand_quantity.to_i.zero?
    return if inventory_value_cents.to_i.zero?

    errors.add(:inventory_value_cents, "must be zero when on-hand quantity is zero")
  end
end
