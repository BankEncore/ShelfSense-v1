# frozen_string_literal: true

class TenderType < ApplicationRecord
  include UuidV7PrimaryKey
  include HasMachineCode

  CATEGORIES = %w[cash card check stored_value other].freeze
  REFERENCE_POLICIES = %w[omitted optional required].freeze
  SYSTEM_CODES = %w[cash card check store_credit trade_credit gift_card].freeze
  STORED_VALUE_ACCOUNT_TYPES = %w[store_credit trade_credit gift_card].freeze

  has_many :pos_tenders, foreign_key: :tender_type_id, inverse_of: :configured_tender_type, dependent: :restrict_with_exception

  validates :code, :name, :behavioral_category, :external_reference_policy, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :behavioral_category, inclusion: { in: CATEGORIES }
  validates :external_reference_policy, inclusion: { in: REFERENCE_POLICIES }
  validates :stored_value_account_type, inclusion: { in: STORED_VALUE_ACCOUNT_TYPES }, allow_nil: true
  validate :protected_identity_rules
  validate :stored_value_account_type_matches_category
  validate :unprotected_category_is_other
  validate :cash_keeps_omitted_reference
  validate :cash_keeps_allows_refund
  before_destroy :prevent_system_identity_destroy

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:behavioral_category, :code) }
  scope :cashier_selectable, -> {
    active.order(
      Arel.sql("CASE behavioral_category WHEN 'cash' THEN 0 WHEN 'card' THEN 1 WHEN 'check' THEN 2 WHEN 'stored_value' THEN 3 ELSE 4 END"),
      :code
    )
  }
  scope :refund_selectable, -> { cashier_selectable.where(allows_refund: true) }

  def admin_label
    name
  end

  def cash?
    behavioral_category == "cash"
  end

  def stored_value?
    behavioral_category == "stored_value"
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
      code: code,
      name: name,
      category: behavioral_category,
      reference_policy: external_reference_policy,
      allows_refund: allows_refund,
      stored_value_account_type: stored_value_account_type,
      allows_original_tender_refund: allows_original_tender_refund,
      allows_generic_refund_destination: allows_generic_refund_destination,
      allows_refund_instrument_replacement: allows_refund_instrument_replacement
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
    if stored_value? && will_save_change_to_stored_value_account_type? && persisted?
      errors.add(:stored_value_account_type, "cannot be changed for a system identity")
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

  def stored_value_account_type_matches_category
    if stored_value?
      errors.add(:stored_value_account_type, "is required for stored-value tenders") if stored_value_account_type.blank?
    elsif stored_value_account_type.present?
      errors.add(:stored_value_account_type, "must be blank unless stored value")
    end
  end
end
