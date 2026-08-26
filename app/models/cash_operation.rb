# frozen_string_literal: true

class CashOperation < ApplicationRecord
  OPERATION_TYPES = %w[initialize_safe transfer paid_in paid_out reconcile reverse].freeze

  belongs_to :store
  belongs_to :performed_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :pos_session, optional: true
  belongs_to :idempotency_operation
  belongs_to :reversal_of, class_name: "CashOperation", optional: true
  has_one :reversed_by, class_name: "CashOperation", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception
  has_many :cash_entries, -> { order(:entry_sequence) }, dependent: :restrict_with_exception
  has_one :cash_transfer, dependent: :restrict_with_exception
  has_one :cash_reconciliation, dependent: :restrict_with_exception
  has_one :cash_safe_initialization, dependent: :restrict_with_exception
  has_one :cash_paid_in, dependent: :restrict_with_exception
  has_one :cash_paid_out, dependent: :restrict_with_exception

  validates :operation_type, :business_date, :occurred_at, presence: true
  validates :operation_type, inclusion: { in: OPERATION_TYPES }
  validate :approver_differs_from_performer

  def readonly?
    super || persisted?
  end

  def reverse?
    operation_type == "reverse"
  end

  def reversed?
    reversed_by.present?
  end

  private

  def approver_differs_from_performer
    return if approved_by_id.blank? || performed_by_id.blank?
    return if approved_by_id != performed_by_id

    errors.add(:approved_by_id, "must differ from the performer")
  end
end
