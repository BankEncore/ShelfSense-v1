# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze
  VARIANT_TYPES = %w[standard used].freeze
  INVENTORY_MODES = MerchandiseClass::INVENTORY_MODES
  PRICING_METHODS = MerchandiseClass::PRICING_METHODS

  attr_accessor :identifier_writes_enabled

  belongs_to :product
  belongs_to :merchandise_condition, optional: true
  belongs_to :merchandise_class, optional: true
  belongs_to :tax_class_override, class_name: "TaxClass", optional: true

  validates :sku, :status, :variant_type, presence: true
  validates :sku, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :industry_identifier, uniqueness: true, allow_nil: true, format: { with: /\A\d{13}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :variant_type, inclusion: { in: VARIANT_TYPES }
  validates :inventory_mode, inclusion: { in: INVENTORY_MODES }, allow_nil: true
  validates :pricing_method, inclusion: { in: PRICING_METHODS }, allow_nil: true
  validates :regular_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :target_margin_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10_000 },
            allow_nil: true
  validate :condition_matches_variant_type
  validate :validate_changed_references
  validate :identifier_write_rules
  validate :tracking_immutability_after_history
  validate :block_class_reclassification_after_history
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

  def department
    merchandise_class&.department
  end

  def effective_tax_class
    tax_class_override || merchandise_class&.default_tax_class
  end

  def derived_inventory_tracking
    self.class.derived_inventory_tracking_for(
      inventory_mode: inventory_mode,
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

  def pos_line_history?
    PosTransactionLine.exists?(product_variant_id: id)
  end

  def sellable?
    status == "active" &&
      product.active_status? &&
      sku.present? &&
      merchandise_class&.assignable? &&
      department&.assignable? &&
      effective_tax_class&.assignable? &&
      inventory_mode.present? &&
      pricing_method.present? &&
      !supplier_returnable.nil? &&
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
        inventory_mode == "inventory"
    else
      false
    end
  end

  def price_satisfies_pricing_method?
    return false if pricing_method.blank?

    case pricing_method
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

    mode_changing = inventory_mode_changed?
    type_changing = variant_type_changed?
    class_changing = merchandise_class_id_changed?
    return unless mode_changing || type_changing || class_changing

    prior_mode = mode_changing ? inventory_mode_was : inventory_mode
    prior_type = type_changing ? variant_type_was : variant_type
    prior = self.class.derived_inventory_tracking_for(inventory_mode: prior_mode, variant_type: prior_type)
    current = derived_inventory_tracking
    return if prior == current

    errors.add(:base, "cannot change inventory tracking method after inventory history exists")
  end

  def block_class_reclassification_after_history
    return if new_record?
    return unless merchandise_class_id_changed?
    return unless inventory_history? || pos_line_history?

    errors.add(
      :merchandise_class_id,
      "cannot be changed after inventory or POS history exists; a controlled reclassification is required"
    )
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
    if tax_class_override_id_changed? && tax_class_override.present? && !tax_class_override.assignable?
      errors.add(:tax_class_override_id, "must be an active tax class")
    end
  end

  def activation_requirements
    errors.add(:merchandise_class_id, "is required to activate") if merchandise_class_id.blank?
    errors.add(:inventory_mode, "is required to activate") if inventory_mode.blank?
    errors.add(:pricing_method, "is required to activate") if pricing_method.blank?
    errors.add(:supplier_returnable, "is required to activate") if supplier_returnable.nil?
    if effective_tax_class.blank?
      errors.add(:base, "an effective tax class is required to activate")
    elsif !effective_tax_class.assignable?
      errors.add(:base, "effective tax class must be an active tax class")
    end
    if merchandise_class.present? && (department.blank? || !department.assignable?)
      errors.add(:base, "merchandise class department must be active")
    end

    require_assignable_condition = status_changed? || merchandise_condition_id_changed?
    unless type_and_condition_valid_for_class?(require_assignable_condition: require_assignable_condition)
      if used? && inventory_mode == "non_inventory"
        errors.add(:inventory_mode, "used variants cannot use non_inventory")
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
