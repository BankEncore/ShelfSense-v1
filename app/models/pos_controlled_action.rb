# frozen_string_literal: true

class PosControlledAction < ApplicationRecord
  ACTION_TYPES = %w[price_override line_discount tax_class_override unlinked_return post_void gift_card_cash_out].freeze
  POLICY_RESULTS = %w[direct approval_required].freeze
  POLICY_VERSION = "phase6_permission_tier_v1"
  FINGERPRINT_SCHEMA_VERSION = "v1"

  belongs_to :pos_transaction, optional: true
  belongs_to :pos_transaction_line, optional: true
  belongs_to :gift_card_cash_out, optional: true
  belongs_to :performed_by_user, class_name: "User"
  belongs_to :approved_by_user, class_name: "User", optional: true

  validates :action_type, :performed_by_name_snapshot, :reason_code, :reason_name_snapshot,
            :policy_result, :policy_version, :fingerprint_schema_version, :action_fingerprint,
            :executed_at, presence: true
  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :policy_result, inclusion: { in: POLICY_RESULTS }
  validates :action_type, uniqueness: { scope: :pos_transaction_line_id }, if: -> { pos_transaction_line_id.present? }
  validate :approver_matches_policy

  def readonly?
    super || (persisted? && (pos_transaction&.commercially_immutable? || gift_card_cash_out_id.present?))
  end

  private

  def approver_matches_policy
    if policy_result == "approval_required"
      errors.add(:approved_by_user_id, "is required") if approved_by_user_id.blank?
      errors.add(:approved_by_name_snapshot, "is required") if approved_by_name_snapshot.blank?
    else
      errors.add(:approved_by_user_id, "must be blank") if approved_by_user_id.present?
      errors.add(:approved_by_name_snapshot, "must be blank") if approved_by_name_snapshot.present?
    end
    return if approved_by_user_id.blank? || performed_by_user_id.blank?
    return if approved_by_user_id != performed_by_user_id

    errors.add(:approved_by_user_id, "must differ from the performer")
  end
end
