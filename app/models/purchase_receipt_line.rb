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
    sum_correction_quantity(select_quantity_reversals)
  end

  def compensated_quantity
    sum_correction_quantity(select_compensating_corrections)
  end

  def remaining_reversible_quantity
    received_quantity - reversed_quantity - compensated_quantity
  end

  def cost_correction_value_cents
    sum_value_deltas(select_cost_corrections)
  end

  # Economic extended value still attributed to this line (original + all correction deltas).
  def effective_merchandise_value_cents
    merchandise_value_cents + all_correction_value_deltas_cents
  end

  def effective_unit_cost_cents
    remaining = remaining_reversible_quantity
    return nil if remaining.zero?

    (effective_merchandise_value_cents.to_d / remaining).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  # Value to remove for quantity Q of the current remaining reversible pool.
  def reversal_value_cents_for(quantity, remaining_before: nil)
    qty = quantity.to_i
    remaining = remaining_before.nil? ? remaining_reversible_quantity : remaining_before.to_i
    raise ArgumentError, "quantity must be positive" unless qty.positive?
    raise ArgumentError, "quantity exceeds remaining reversible" if qty > remaining
    return 0 if remaining.zero?

    if qty == remaining
      effective_merchandise_value_cents_excluding_pending
    else
      (
        effective_merchandise_value_cents_excluding_pending.to_d * qty / remaining
      ).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end
  end

  # Reversals and compensations consume matched quantity first, then unplanned.
  def reversed_matched_quantity
    remaining_matched = matched_quantity
    ordered_quantity_consuming_corrections.each do |correction|
      take = [ correction.quantity.to_i, remaining_matched ].min
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

  def effective_merchandise_value_cents_excluding_pending
    # Callers that already inserted the in-flight correction should pass remaining_before
    # and rely on value_deltas excluding that correction via reload/association state.
    effective_merchandise_value_cents
  end

  def all_correction_value_deltas_cents
    if corrections.loaded?
      corrections.sum { |c| c.value_delta_cents.to_i }
    else
      corrections.sum(:value_delta_cents).to_i
    end
  end

  def select_quantity_reversals
    if corrections.loaded?
      corrections.select(&:quantity_reversal?)
    else
      corrections.quantity_reversals.to_a
    end
  end

  def select_compensating_corrections
    if corrections.loaded?
      corrections.select(&:compensating_adjustment_reference?)
    else
      corrections.compensating_references.to_a
    end
  end

  def select_cost_corrections
    if corrections.loaded?
      corrections.select(&:cost_correction?)
    else
      corrections.cost_corrections.to_a
    end
  end

  def sum_correction_quantity(list)
    list.sum { |c| c.quantity.to_i }
  end

  def sum_value_deltas(list)
    list.sum { |c| c.value_delta_cents.to_i }
  end

  def ordered_quantity_consuming_corrections
    if corrections.loaded?
      corrections
        .select { |c| c.quantity_reversal? || c.compensating_adjustment_reference? }
        .sort_by { |c| [ c.recorded_at, c.id ] }
    else
      corrections
        .where(correction_type: %w[quantity_reversal compensating_adjustment_reference])
        .order(:recorded_at, :id)
        .to_a
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
