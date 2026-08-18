# frozen_string_literal: true

class PosTransactionLine < ApplicationRecord
  DIRECTIONS = %w[sale].freeze
  SNAPSHOT_KEYS = %w[sku description tax_class_code].freeze
  UNIT_SNAPSHOT_KEYS = %w[unit_identifier condition_code].freeze

  belongs_to :pos_transaction
  belongs_to :product_variant
  belongs_to :tax_class
  belongs_to :inventory_unit, optional: true
  has_many :pos_line_tax_components, dependent: :destroy

  validates :line_number, :direction, :quantity, :reference_unit_price_cents, :selling_unit_price_cents,
            :extended_selling_amount_cents, :tax_class_code_snapshot, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :pos_transaction_id }
  validate :inventory_unit_matches_tracking
  validate :merchandise_snapshot_complete, if: -> { pos_transaction&.completed? }

  def unit_line?
    inventory_unit_id.present?
  end

  def recalc_extended!
    self.extended_selling_amount_cents = selling_unit_price_cents * quantity
    self.line_total_cents = extended_selling_amount_cents + line_tax_cents
  end

  def readonly?
    super || (persisted? && pos_transaction&.commercially_immutable?)
  end

  private

  def inventory_unit_matches_tracking
    tracking = product_variant&.derived_inventory_tracking
    if inventory_unit_id.present? && quantity != 1
      errors.add(:quantity, "must be 1 when an inventory unit is present")
    end
    if inventory_unit && product_variant_id && inventory_unit.product_variant_id != product_variant_id
      errors.add(:inventory_unit_id, "must belong to the line's variant")
    end
    if tracking == "individual"
      errors.add(:inventory_unit_id, "is required for individually tracked merchandise") if inventory_unit_id.blank?
      errors.add(:quantity, "must be 1 for individually tracked merchandise") unless quantity == 1
    elsif inventory_unit_id.present?
      errors.add(:inventory_unit_id, "must be blank unless the line is individually tracked")
    end
  end

  def merchandise_snapshot_complete
    snapshot = merchandise_snapshot
    unless snapshot.is_a?(Hash) && SNAPSHOT_KEYS.all? { |key| snapshot[key].present? }
      errors.add(:merchandise_snapshot, "must include sku, description, and tax_class_code")
      return
    end
    return unless unit_line?

    unless UNIT_SNAPSHOT_KEYS.all? { |key| snapshot[key].present? }
      errors.add(:merchandise_snapshot, "must include unit_identifier and condition_code")
    end
  end
end
