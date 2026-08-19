# frozen_string_literal: true

class TenderType < ApplicationRecord
  include UuidV7PrimaryKey
  include HasMachineCode

  CATEGORIES = %w[cash card check other].freeze
  REFERENCE_POLICIES = %w[omitted optional required].freeze
  SYSTEM_CODES = %w[cash card check].freeze

  has_many :pos_tenders, foreign_key: :tender_type_id, inverse_of: :configured_tender_type, dependent: :restrict_with_exception

  validates :code, :name, :behavioral_category, :external_reference_policy, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :behavioral_category, inclusion: { in: CATEGORIES }
  validates :external_reference_policy, inclusion: { in: REFERENCE_POLICIES }
  validate :protected_identity_rules
  validate :unprotected_category_is_other
  validate :cash_keeps_omitted_reference
  validate :cash_keeps_allows_refund
  before_destroy :prevent_system_identity_destroy

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:behavioral_category, :code) }
  scope :cashier_selectable, -> {
    active.order(
      Arel.sql("CASE behavioral_category WHEN 'cash' THEN 0 WHEN 'card' THEN 1 WHEN 'check' THEN 2 ELSE 3 END"),
      :code
    )
  }

  def admin_label
    name
  end

  def cash?
    behavioral_category == "cash"
  end

  def other?
    behavioral_category == "other"
  end

  def reference_required?
    external_reference_policy == "required"
  end

  def reference_captured?
    external_reference_policy != "omitted"
  end

  def reference_field_label
    case external_reference_policy
    when "required" then "Reference (required)"
    when "optional" then "Reference (optional)"
    else "Reference"
    end
  end

  def cashier_payload
    {
      id: id.to_s,
      name: name,
      category: behavioral_category,
      reference_policy: external_reference_policy
    }
  end

  def reactivation_blockers
    []
  end

  def assignable?
    active?
  end

  private

  def protected_identity_rules
    return unless system_protected?

    if will_save_change_to_behavioral_category? && persisted?
      errors.add(:behavioral_category, "cannot be changed for a system identity")
    end
    if will_save_change_to_code? && persisted?
      errors.add(:code, "cannot be changed for a system identity")
    end
    if cash? && will_save_change_to_active? && !active?
      errors.add(:active, "cannot deactivate Cash")
    end
  end

  def unprotected_category_is_other
    return if system_protected?
    return if behavioral_category.blank? || other?

    errors.add(:behavioral_category, "must be other for admin-created identities")
  end

  def prevent_system_identity_destroy
    return unless system_protected?

    errors.add(:base, "system identities cannot be deleted")
    throw :abort
  end

  def cash_keeps_omitted_reference
    return unless cash?
    return if external_reference_policy == "omitted"

    errors.add(:external_reference_policy, "must be omitted for Cash")
  end

  def cash_keeps_allows_refund
    return unless cash?
    return if allows_refund

    errors.add(:allows_refund, "must remain true for Cash")
  end
end
