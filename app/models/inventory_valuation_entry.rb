# frozen_string_literal: true

class InventoryValuationEntry < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :store
  belongs_to :product_variant
  belongs_to :inventory_unit, optional: true
  belongs_to :reversal_of, class_name: "InventoryValuationEntry", optional: true

  validates :quantity_delta, :value_delta_cents, :valuation_method, :entry_type, :source_type, :source_id,
            :business_date, :occurred_at, presence: true
end
