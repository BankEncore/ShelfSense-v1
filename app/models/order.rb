# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :store
  belongs_to :product_variant
  belongs_to :supplier
  belongs_to :customer_request, optional: true
  belongs_to :replaces_order, class_name: "Order", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_one :purchase_order_line, dependent: :restrict_with_exception
  has_one :purchase_order, through: :purchase_order_line

  validates :number, :requested_quantity, presence: true
  validates :number, uniqueness: { scope: :store_id }
  validates :requested_quantity, numericality: { only_integer: true, greater_than: 0 }
  validate :variant_must_be_standard_inventory_bearing
  validate :customer_order_quantity_one
  validate :customer_order_matches_request

  scope :active, -> { where(cancelled_at: nil) }
  scope :for_store, ->(store) { where(store_id: store.id) }
  scope :admin_ordered, -> { order(number: :desc) }

  def cancelled?
    cancelled_at.present?
  end

  def customer_order?
    customer_request_id.present?
  end

  def stock_order?
    customer_request_id.blank?
  end

  def unsent?
    return true if purchase_order_line.blank?

    purchase_order.status == "draft"
  end

  def admin_label
    "Order ##{number}"
  end

  private

  def variant_must_be_standard_inventory_bearing
    return if product_variant.blank?

    unless product_variant.standard?
      errors.add(:product_variant_id, "must be a Standard variant")
      return
    end

    unless product_variant.inventory_mode == "inventory"
      errors.add(:product_variant_id, "must be inventory-bearing")
    end

    unless product_variant.status == "active"
      errors.add(:product_variant_id, "must be active")
    end
  end

  def customer_order_quantity_one
    return unless customer_order?
    return if requested_quantity == 1

    errors.add(:requested_quantity, "must be 1 for a customer special order")
  end

  def customer_order_matches_request
    return if customer_request.blank?

    if store_id != customer_request.store_id
      errors.add(:store_id, "must match the customer request store")
    end
    if product_variant_id != customer_request.product_variant_id
      errors.add(:product_variant_id, "must match the customer request variant")
    end
  end
end
