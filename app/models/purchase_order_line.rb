# frozen_string_literal: true

class PurchaseOrderLine < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :order
  belongs_to :product_variant
  has_one :line_state, class_name: "PurchaseOrderLineState", dependent: :restrict_with_exception
  has_many :cancellations, class_name: "PurchaseOrderLineCancellation", dependent: :restrict_with_exception
  has_many :purchase_receipt_lines, dependent: :restrict_with_exception

  validates :ordered_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :expected_unit_cost_cents_snapshot,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :order_id, uniqueness: true
  validate :variant_must_match_order
  validate :variant_must_be_standard_inventory_bearing

  scope :with_positive_open_quantity, -> {
    where(<<~SQL.squish)
      purchase_order_lines.ordered_quantity
      - COALESCE((
          SELECT SUM(polc.quantity)
          FROM purchase_order_line_cancellations polc
          WHERE polc.purchase_order_line_id = purchase_order_lines.id
        ), 0)
      > COALESCE((
          SELECT SUM(
            purchase_receipt_lines.matched_quantity
            - LEAST(
                purchase_receipt_lines.matched_quantity,
                COALESCE((
                  SELECT SUM(prlc.quantity)
                  FROM purchase_receipt_line_corrections prlc
                  WHERE prlc.purchase_receipt_line_id = purchase_receipt_lines.id
                    AND prlc.correction_type IN ('quantity_reversal', 'compensating_adjustment_reference')
                ), 0)
              )
          )
          FROM purchase_receipt_lines
          INNER JOIN purchase_receipts ON purchase_receipts.id = purchase_receipt_lines.purchase_receipt_id
          WHERE purchase_receipt_lines.purchase_order_line_id = purchase_order_lines.id
            AND purchase_receipts.status = 'posted'
        ), 0)
    SQL
  }

  def expected_extended_cents
    ordered_quantity * expected_unit_cost_cents_snapshot
  end

  def posted_matched_quantity
    posted_lines =
      if purchase_receipt_lines.loaded?
        purchase_receipt_lines.select { |line| line.purchase_receipt&.status == "posted" }
      else
        purchase_receipt_lines
          .joins(:purchase_receipt)
          .where(purchase_receipts: { status: "posted" })
          .includes(:corrections, :purchase_receipt)
          .to_a
      end
    posted_lines.sum(&:net_matched_quantity)
  end

  def cancelled_quantity
    if cancellations.loaded?
      cancellations.sum(&:quantity)
    else
      cancellations.sum(:quantity)
    end
  end

  def open_quantity
    ordered_quantity - posted_matched_quantity - cancelled_quantity
  end

  private

  def variant_must_match_order
    return if order.blank? || product_variant_id.blank?
    return if product_variant_id == order.product_variant_id

    errors.add(:product_variant_id, "must match the order variant")
  end

  def variant_must_be_standard_inventory_bearing
    return if product_variant.blank?

    unless product_variant.standard?
      errors.add(:product_variant_id, "must be a Standard variant")
      return
    end

    unless product_variant.inventory_mode == "inventory"
      errors.add(:product_variant_id, "must be inventory-bearing")
    end
  end
end
