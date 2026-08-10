# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze

  belongs_to :product
  belongs_to :merchandise_condition
  belongs_to :merchandise_class, optional: true
  belongs_to :department, optional: true
  belongs_to :tax_class, optional: true

  validates :sku, :status, :merchandise_condition_id, presence: true
  validates :sku, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :industry_identifier, uniqueness: true, allow_nil: true, format: { with: /\A\d{13}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :regular_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :validate_changed_references
  validate :sku_immutable, on: :update
  validate :activation_requirements, if: -> { status_changed? && status == "active" }

  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }

  def draft?
    status == "draft"
  end

  def sellable?
    status == "active" &&
      product.active_status? &&
      sku.present? &&
      merchandise_class&.assignable? &&
      merchandise_condition&.assignable? &&
      department&.assignable? &&
      tax_class&.assignable? &&
      condition_allowed_by_class? &&
      price_satisfies_pricing_method?
  end

  def condition_allowed_by_class?
    return false if merchandise_class.blank? || merchandise_condition.blank?
    return true unless merchandise_condition.used_basis?

    merchandise_class.used_merchandise_allowed?
  end

  def price_satisfies_pricing_method?
    return false if merchandise_class.blank?

    case merchandise_class.pricing_method
    when "open_price"
      true
    when "fixed", "list_price", "cost_based"
      regular_price_cents.present? && regular_price_cents >= 0
    else
      false
    end
  end

  private

  def sku_immutable
    errors.add(:sku, "cannot be changed") if sku_changed?
  end

  def validate_changed_references
    if merchandise_condition_id_changed? && merchandise_condition.present? && !merchandise_condition.assignable?
      errors.add(:merchandise_condition_id, "must be an active condition")
    end
    if merchandise_class_id_changed? && merchandise_class.present? && !merchandise_class.assignable?
      errors.add(:merchandise_class_id, "must be an active merchandise class")
    end
    if department_id_changed? && department.present? && !department.assignable?
      errors.add(:department_id, "must be an active department")
    end
    if tax_class_id_changed? && tax_class.present? && !tax_class.assignable?
      errors.add(:tax_class_id, "must be an active tax class")
    end
  end

  def activation_requirements
    errors.add(:merchandise_class_id, "is required to activate") if merchandise_class_id.blank?
    errors.add(:department_id, "is required to activate") if department_id.blank?
    errors.add(:tax_class_id, "is required to activate") if tax_class_id.blank?
    errors.add(:base, "condition is not allowed for this merchandise class") unless condition_allowed_by_class?
    errors.add(:regular_price_cents, "is required for this pricing method") unless price_satisfies_pricing_method?
    errors.add(:product_id, "product must be active") unless product.active_status?
  end
end
