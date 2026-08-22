# frozen_string_literal: true

class PurchaseOrderLineCancellation < ApplicationRecord
  SOURCES = %w[buyer supplier].freeze

  belongs_to :purchase_order_line
  belongs_to :recorded_by, class_name: "User"

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :reason, :occurred_at, presence: true
end
