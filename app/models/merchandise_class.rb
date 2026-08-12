# frozen_string_literal: true

class MerchandiseClass < ApplicationRecord
  include HasMachineCode

  INVENTORY_MODES = %w[inventory non_inventory].freeze
  PRICING_METHODS = %w[fixed list_price cost_based open_price].freeze

  belongs_to :default_standard_department, class_name: "Department", optional: true
  belongs_to :default_used_department, class_name: "Department", optional: true

  validates :code, :name, :inventory_mode, :pricing_method, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :inventory_mode, inclusion: { in: INVENTORY_MODES }
  validates :pricing_method, inclusion: { in: PRICING_METHODS }
  validate :validate_changed_departments
  validate :buyback_implication

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:display_order, :name) }

  def assignable?
    active?
  end

  def admin_label
    name
  end

  def self.options_for_select(records = admin_ordered)
    Array(records).map { |klass| [ klass.admin_label, klass.id ] }
  end

  def inventory?
    inventory_mode == "inventory"
  end

  def non_inventory?
    inventory_mode == "non_inventory"
  end

  def reactivation_blockers
    blockers = []
    if default_standard_department.present? && !default_standard_department.active?
      blockers << "default standard department must be active"
    end
    if default_used_department.present? && !default_used_department.active?
      blockers << "default used department must be active"
    end
    blockers
  end

  private

  def validate_changed_departments
    if default_standard_department_id_changed? && default_standard_department.present? && !default_standard_department.assignable?
      errors.add(:default_standard_department_id, "must be an active department")
    end
    if default_used_department_id_changed? && default_used_department.present? && !default_used_department.assignable?
      errors.add(:default_used_department_id, "must be an active department")
    end
  end

  def buyback_implication
    return unless buyback_allowed?

    unless used_merchandise_allowed? && inventory?
      errors.add(:buyback_allowed, "requires used merchandise allowed and inventory mode")
    end
  end
end
