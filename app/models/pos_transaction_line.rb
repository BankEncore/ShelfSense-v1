# frozen_string_literal: true

class PosTransactionLine < ApplicationRecord
  DIRECTIONS = %w[sale return].freeze
  SNAPSHOT_KEYS = %w[sku description tax_class_code].freeze
  UNIT_SNAPSHOT_KEYS = %w[unit_identifier condition_code].freeze

  belongs_to :pos_transaction
  belongs_to :product_variant
  belongs_to :tax_class
  belongs_to :default_tax_class, class_name: "TaxClass", optional: true
  belongs_to :inventory_unit, optional: true
  belongs_to :original_transaction_line, class_name: "PosTransactionLine", optional: true
  has_many :pos_line_tax_components, dependent: :destroy
  has_many :pos_controlled_actions, dependent: :destroy

  validates :line_number, :direction, :quantity, :reference_unit_price_cents, :selling_unit_price_cents,
            :extended_selling_amount_cents, :tax_class_code_snapshot, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :line_number, uniqueness: { scope: :pos_transaction_id }
  validate :inventory_unit_matches_tracking
  validate :merchandise_snapshot_complete, if: -> { pos_transaction&.completed? }
  validate :return_reason_rules

  def sale?
    direction == "sale"
  end

  def return?
    direction == "return"
  end

  def linked_return?
    return? && original_transaction_line_id.present?
  end

  def unlinked_return?
    return? && original_transaction_line_id.blank?
  end

  def unit_line?
    inventory_unit_id.present?
  end

  def price_overridden?
    sale? && selling_unit_price_cents != reference_unit_price_cents
  end

  def manually_discounted?
    sale? && manual_discount_basis_points.present?
  end

  def tax_class_overridden?
    sale? && default_tax_class_id.present? && tax_class_id != default_tax_class_id
  end

  def recalc_extended!
    raise Pos::Error, "linked returns cannot use sale-line recalculation" if linked_return?

    self.extended_selling_amount_cents = selling_unit_price_cents * quantity
    self.manual_discount_cents ||= 0
    if manual_discount_basis_points.present?
      self.manual_discount_cents = Pos::LineDiscount.amount_cents(
        selling_unit_price_cents: selling_unit_price_cents,
        quantity: quantity,
        basis_points: manual_discount_basis_points
      )
    else
      self.manual_discount_cents = 0
    end
    self.net_merchandise_amount_cents = extended_selling_amount_cents - manual_discount_cents
    self.line_total_cents = net_merchandise_amount_cents + line_tax_cents
  end

  def readonly?
    super || (persisted? && pos_transaction&.commercially_immutable?)
  end

  private

  def return_reason_rules
    if sale?
      if original_transaction_line_id.present? || return_reason_code.present? ||
         return_reason_name_snapshot.present? || return_reason_note.present?
        errors.add(:base, "sale lines cannot have return fields")
      end
      return
    end
    return unless return?

    errors.add(:return_reason_code, "is required") if return_reason_code.blank?
    errors.add(:return_reason_name_snapshot, "is required") if return_reason_name_snapshot.blank?
    if return_reason_code.present? && Pos::ReturnReasons::CODES.exclude?(return_reason_code)
      errors.add(:return_reason_code, "is not included in the list")
    end
    if Pos::ReturnReasons.require_note?(return_reason_code)
      errors.add(:return_reason_note, "is required") if return_reason_note.blank?
      errors.add(:return_reason_note, "is too long") if return_reason_note.to_s.length > 200
    elsif return_reason_note.present?
      errors.add(:return_reason_note, "must be blank unless the reason is other")
    end
  end

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
