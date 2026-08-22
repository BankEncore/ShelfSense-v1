# frozen_string_literal: true

class PurchaseReceiptLine < ApplicationRecord
  belongs_to :purchase_receipt
  belongs_to :purchase_order_line
  belongs_to :product_variant
  has_one :customer_request_allocation, dependent: :restrict_with_exception
  has_many :corrections, class_name: "PurchaseReceiptLineCorrection", dependent: :restrict_with_exception

  validates :received_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :matched_quantity, :unplanned_quantity,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :actual_unit_cost_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :purchase_order_line_id, uniqueness: { scope: :purchase_receipt_id }
  validate :quantities_must_add_up
  validate :variant_must_match_po_line
  validate :po_must_match_receipt_store_and_supplier

  def merchandise_value_cents
    received_quantity * actual_unit_cost_cents
  end

  def reversed_quantity
    if corrections.loaded?
      corrections.select(&:quantity_reversal?).sum { |c| c.quantity.to_i }
    else
      corrections.quantity_reversals.sum(:quantity)
    end
  end

  def remaining_reversible_quantity
    received_quantity - reversed_quantity
  end

  # Reversals consume matched quantity first, then unplanned.
  def reversed_matched_quantity
    remaining_matched = matched_quantity
    ordered_quantity_reversals.each do |correction|
      take = [ correction.quantity, remaining_matched ].min
      remaining_matched -= take
    end
    matched_quantity - remaining_matched
  end

  def net_matched_quantity
    matched_quantity - reversed_matched_quantity
  end

  def fully_reversed?
    remaining_reversible_quantity.zero?
  end

  private

  def ordered_quantity_reversals
    if corrections.loaded?
      corrections.select(&:quantity_reversal?).sort_by { |c| [ c.recorded_at, c.id ] }
    else
      corrections.quantity_reversals.order(:recorded_at, :id).to_a
    end
  end

  def quantities_must_add_up
    return if received_quantity.blank? || matched_quantity.blank? || unplanned_quantity.blank?
    return if matched_quantity + unplanned_quantity == received_quantity

    errors.add(:base, "matched and unplanned quantities must equal received quantity")
  end

  def variant_must_match_po_line
    return if purchase_order_line.blank? || product_variant_id.blank?
    return if product_variant_id == purchase_order_line.product_variant_id

    errors.add(:product_variant_id, "must match the purchase order line variant")
  end

  def po_must_match_receipt_store_and_supplier
    return if purchase_receipt.blank? || purchase_order_line.blank?

    po = purchase_order_line.purchase_order
    return if po.blank?

    if po.store_id != purchase_receipt.store_id
      errors.add(:purchase_order_line_id, "must belong to a PO for this store")
    end
    if po.supplier_id != purchase_receipt.supplier_id
      errors.add(:purchase_order_line_id, "must belong to a PO for this supplier")
    end
  end
end
