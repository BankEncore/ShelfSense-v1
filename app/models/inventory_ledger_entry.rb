# frozen_string_literal: true

class InventoryLedgerEntry < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :store
  belongs_to :product_variant
  belongs_to :inventory_unit, optional: true
  belongs_to :reversal_of, class_name: "InventoryLedgerEntry", optional: true

  validates :quantity_delta, :entry_type, :source_type, :source_id, :business_date, :occurred_at, :actor_type, :actor_id,
            presence: true
end
