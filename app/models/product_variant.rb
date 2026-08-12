# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze
  VARIANT_TYPES = %w[standard used].freeze

  attr_accessor :identifier_writes_enabled

  belongs_to :product
  belongs_to :merchandise_condition, optional: true
  belongs_to :merchandise_class, optional: true
  belongs_to :department, optional: true
  belongs_to :tax_class, optional: true

  validates :sku, :status, :variant_type, presence: true
  validates :sku, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :industry_identifier, uniqueness: true, allow_nil: true, format: { with: /\A\d{13}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :variant_type, inclusion: { in: VARIANT_TYPES }
  validates :regular_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :condition_matches_variant_type
  validate :validate_changed_references
  validate :identifier_write_rules
  validate :tracking_immutability_after_history
  validate :activation_requirements, if: -> { status == "active" }
  after_save { self.identifier_writes_enabled = false }

  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }
  scope :standard, -> { where(variant_type: "standard") }
  scope :used, -> { where(variant_type: "used") }

  def draft?
    status == "draft"
  end

  def standard?
    variant_type == "standard"
  end

  def used?
    variant_type == "used"
  end

  def derived_inventory_tracking
    self.class.derived_inventory_tracking_for(
      inventory_mode: merchandise_class&.inventory_mode,
      variant_type: variant_type
    )
  end

  def self.derived_inventory_tracking_for(inventory_mode:, variant_type:)
    return nil if inventory_mode.blank? || variant_type.blank?

    case [ inventory_mode, variant_type ]
    when %w[inventory standard] then "quantity"
    when %w[inventory used] then "individual"
    when %w[non_inventory standard] then "non_inventory"
    end
  end

  def inventory_history?
    InventoryBalance.exists?(product_variant_id: id) ||
      InventoryLedgerEntry.exists?(product_variant_id: id) ||
      InventoryValuationEntry.exists?(product_variant_id: id) ||
      InventoryUnit.exists?(product_variant_id: id)
  end

  def sellable?
    status == "active" &&
      product.active_status? &&
      sku.present? &&
      merchandise_class&.assignable? &&
      department&.assignable? &&
      tax_class&.assignable? &&
      type_and_condition_valid_for_class?(require_assignable_condition: true) &&
      price_satisfies_pricing_method?
  end

  def type_and_condition_valid_for_class?(require_assignable_condition: true)
    return false if merchandise_class.blank?

    if standard?
      merchandise_condition_id.blank?
    elsif used?
      condition_ok =
        if require_assignable_condition
          merchandise_condition&.assignable?
        else
          merchandise_condition.present?
        end
      condition_ok &&
        merchandise_class.used_merchandise_allowed? &&
        merchandise_class.inventory?
    else
      false
    end
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

  def identifier_write_rules
    if new_record?
      unless identifier_writes_enabled
        errors.add(:base, "identifiers must be assigned through ProductVariants::Create")
      end
      return
    end

    errors.add(:sku, "cannot be changed") if sku_changed?

    if industry_identifier_changed? && !identifier_writes_enabled
      errors.add(:industry_identifier, "must be changed through Identifiers::AssignIndustry")
    end
  end

  def tracking_immutability_after_history
    return if new_record?
    return unless inventory_history?
    return unless merchandise_class_id_changed? || variant_type_changed?

    prior_class =
      if merchandise_class_id_changed?
        MerchandiseClass.find_by(id: merchandise_class_id_was)
      else
        merchandise_class
      end
    prior_type = variant_type_changed? ? variant_type_was : variant_type
    prior = self.class.new(merchandise_class: prior_class, variant_type: prior_type).derived_inventory_tracking
    current = derived_inventory_tracking
    return if prior == current

    errors.add(:base, "cannot change inventory tracking method after inventory history exists")
  end

  def condition_matches_variant_type
    if standard? && merchandise_condition_id.present?
      errors.add(:merchandise_condition_id, "must be blank for standard variants")
    elsif used? && merchandise_condition_id.blank?
      errors.add(:merchandise_condition_id, "is required for used variants")
    end
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

    require_assignable_condition = status_changed? || merchandise_condition_id_changed?
    unless type_and_condition_valid_for_class?(require_assignable_condition: require_assignable_condition)
      if used? && merchandise_class.present? && merchandise_class.non_inventory?
        errors.add(:merchandise_class_id, "used variants cannot use a non-inventory merchandise class")
      elsif used? && merchandise_class.present? && !merchandise_class.used_merchandise_allowed?
        errors.add(:base, "used variants require a merchandise class that allows used merchandise")
      elsif used? && merchandise_condition.blank?
        errors.add(:merchandise_condition_id, "is required for used variants")
      elsif used? && require_assignable_condition && merchandise_condition.present? && !merchandise_condition.assignable?
        errors.add(:merchandise_condition_id, "must be an active condition")
      elsif standard? && merchandise_condition_id.present?
        errors.add(:merchandise_condition_id, "must be blank for standard variants")
      else
        errors.add(:base, "variant type, condition, and merchandise class combination is invalid")
      end
    end
    errors.add(:regular_price_cents, "is required for this pricing method") unless price_satisfies_pricing_method?
    errors.add(:product_id, "product must be active") unless product.active_status?
  end
end
