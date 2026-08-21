# frozen_string_literal: true

class MerchandiseClass < ApplicationRecord
  include HasMachineCode

  INVENTORY_MODES = %w[inventory non_inventory].freeze
  PRICING_METHODS = %w[fixed list_price cost_based open_price].freeze

  belongs_to :department
  belongs_to :default_tax_class, class_name: "TaxClass"
  has_many :product_variants, dependent: :restrict_with_exception

  before_validation :normalize_merchandise_class_number

  validates :code, :name, :merchandise_class_number, :default_inventory_mode, :default_pricing_method, :default_tax_class_id, :department_id, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :merchandise_class_number, uniqueness: { scope: :department_id }
  validates :default_inventory_mode, inclusion: { in: INVENTORY_MODES }
  validates :default_pricing_method, inclusion: { in: PRICING_METHODS }
  validates :target_margin_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10_000 },
            allow_nil: true
  validate :validate_changed_department
  validate :validate_changed_default_tax_class
  validate :buyback_implication
  validate :block_department_move_after_history

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:display_order, :merchandise_class_number, :name) }

  def assignable?
    active?
  end

  def admin_label
    if department
      "#{department.department_number} / #{merchandise_class_number} - #{name}"
    else
      name
    end
  end

  def self.options_for_select(records = admin_ordered.includes(:department))
    Array(records).map { |klass| [ klass.admin_label, klass.id ] }
  end

  def inventory?
    default_inventory_mode == "inventory"
  end

  def non_inventory?
    default_inventory_mode == "non_inventory"
  end

  def reactivation_blockers
    blockers = []
    blockers << "department must be active" if department.blank? || !department.active?
    blockers << "default tax class must be active" if default_tax_class.blank? || !default_tax_class.active?
    blockers
  end

  private

  def normalize_merchandise_class_number
    self.merchandise_class_number = merchandise_class_number.to_s.strip.presence
  end

  def validate_changed_department
    return unless department_id_changed?
    return if department.blank?

    errors.add(:department_id, "must be an active department") unless department.assignable?
  end

  def validate_changed_default_tax_class
    return unless default_tax_class_id_changed?
    return if default_tax_class.blank?

    errors.add(:default_tax_class_id, "must be an active tax class") unless default_tax_class.assignable?
  end

  def buyback_implication
    return unless buyback_allowed?

    unless used_merchandise_allowed? && inventory?
      errors.add(:buyback_allowed, "requires used merchandise allowed and inventory mode")
    end
  end

  def block_department_move_after_history
    return unless department_id_changed?
    return if new_record?
    return if department_id_was.blank?

    product_variants.find_each do |variant|
      next unless variant.inventory_history? || variant.pos_line_history?

      errors.add(:department_id, "cannot be changed after associated variants have inventory or POS history; a controlled reclassification is required")
      break
    end
  end
end
