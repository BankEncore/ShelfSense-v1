# frozen_string_literal: true

class PurchaseReceiptLineCorrection < ApplicationRecord
  CORRECTION_TYPES = %w[
    quantity_reversal
    cost_correction
    compensating_adjustment_reference
  ].freeze

  belongs_to :purchase_receipt_line
  belongs_to :recorded_by, class_name: "User"
  belongs_to :inventory_source, polymorphic: true, optional: true

  validates :correction_type, presence: true, inclusion: { in: CORRECTION_TYPES }
  validates :reason, :recorded_at, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, if: :requires_quantity?
  validates :quantity, absence: true, if: :cost_correction?
  validates :value_delta_cents, presence: true, numericality: { other_than: 0 }, if: :cost_correction?
  validates :value_delta_cents, presence: true, if: :compensating_adjustment_reference?

  scope :quantity_reversals, -> { where(correction_type: "quantity_reversal") }
  scope :cost_corrections, -> { where(correction_type: "cost_correction") }
  scope :compensating_references, -> { where(correction_type: "compensating_adjustment_reference") }

  def quantity_reversal?
    correction_type == "quantity_reversal"
  end

  def cost_correction?
    correction_type == "cost_correction"
  end

  def compensating_adjustment_reference?
    correction_type == "compensating_adjustment_reference"
  end

  def requires_quantity?
    quantity_reversal? || compensating_adjustment_reference?
  end
end
