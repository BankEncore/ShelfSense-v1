# frozen_string_literal: true

class MerchandiseClass < ApplicationRecord
  TRACKING_MODES = %w[quantity individual non_inventory].freeze
  PRICING_METHODS = %w[fixed list_price cost_based open_price].freeze

  belongs_to :default_standard_department, class_name: "Department", optional: true
  belongs_to :default_used_department, class_name: "Department", optional: true

  before_validation :normalize_code

  validates :code, :name, :inventory_tracking_mode, :pricing_method, presence: true
  validates :code, uniqueness: true
  validates :inventory_tracking_mode, inclusion: { in: TRACKING_MODES }
  validates :pricing_method, inclusion: { in: PRICING_METHODS }
  validate :validate_changed_departments

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase.tr(" ", "_")
  end

  def validate_changed_departments
    if default_standard_department_id_changed? && default_standard_department.present? && !default_standard_department.assignable?
      errors.add(:default_standard_department_id, "must be an active department")
    end
    if default_used_department_id_changed? && default_used_department.present? && !default_used_department.assignable?
      errors.add(:default_used_department_id, "must be an active department")
    end
  end
end
