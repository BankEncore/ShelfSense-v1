# frozen_string_literal: true

class StoredValueAdjustment < ApplicationRecord
  DIRECTIONS = %w[credit debit].freeze

  belongs_to :stored_value_account
  belongs_to :reason, class_name: "StoredValueAdjustmentReason"
  belongs_to :store
  belongs_to :performed_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :stored_value_operation, optional: true
  belongs_to :idempotency_operation
  belongs_to :reversal_of, class_name: "StoredValueAdjustment", optional: true
  has_one :reversed_by, class_name: "StoredValueAdjustment", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception

  validates :adjustment_direction, :amount_cents, :reason_code, :reason_name_snapshot, :posted_at, presence: true
  validates :adjustment_direction, inclusion: { in: DIRECTIONS }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def readonly?
    super || persisted?
  end

  def signed_amount_cents
    adjustment_direction == "credit" ? amount_cents : -amount_cents
  end
end
