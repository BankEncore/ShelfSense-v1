# frozen_string_literal: true

class InventoryAdjustment < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :store
  belongs_to :product_variant
  belongs_to :inventory_unit, optional: true
  belongs_to :adjustment_reason
  belongs_to :created_by, class_name: "User"
  belongs_to :reversal_of, class_name: "InventoryAdjustment", optional: true
  has_one :reversed_by_adjustment, class_name: "InventoryAdjustment", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
                                   dependent: :restrict_with_exception

  validates :quantity_delta, :business_date, :occurred_at, :posted_at, presence: true
  validates :quantity_delta, numericality: { other_than: 0, only_integer: true }

  def reversed?
    reversed_at.present?
  end

  def reversal?
    reversal_of_id.present?
  end
end
