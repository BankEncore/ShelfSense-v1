# frozen_string_literal: true

class PurchaseOrderLineState < ApplicationRecord
  self.primary_key = "purchase_order_line_id"

  belongs_to :purchase_order_line

  validates :backordered_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :confirmed_quantity,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true

  private

  # PK is the line FK; never invent a separate UUID.
  def assign_uuid_v7
  end
end
