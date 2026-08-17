# frozen_string_literal: true

class PosTransactionLine < ApplicationRecord
  DIRECTIONS = %w[sale].freeze
  SNAPSHOT_KEYS = %w[sku description tax_class_code].freeze

  belongs_to :pos_transaction
  belongs_to :product_variant
  belongs_to :tax_class
  has_many :pos_line_tax_components, dependent: :destroy

  validates :line_number, :direction, :quantity, :reference_unit_price_cents, :selling_unit_price_cents,
            :extended_selling_amount_cents, :tax_class_code_snapshot, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :pos_transaction_id }
  validate :merchandise_snapshot_complete, if: -> { pos_transaction&.completed? }

  def recalc_extended!
    self.extended_selling_amount_cents = selling_unit_price_cents * quantity
    self.line_total_cents = extended_selling_amount_cents + line_tax_cents
  end

  def readonly?
    super || (persisted? && pos_transaction&.commercially_immutable?)
  end

  private

  def merchandise_snapshot_complete
    snapshot = merchandise_snapshot
    unless snapshot.is_a?(Hash) && SNAPSHOT_KEYS.all? { |key| snapshot[key].present? }
      errors.add(:merchandise_snapshot, "must include sku, description, and tax_class_code")
    end
  end
end
