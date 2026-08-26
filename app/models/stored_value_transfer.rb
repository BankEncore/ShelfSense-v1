# frozen_string_literal: true

class StoredValueTransfer < ApplicationRecord
  TRANSFER_TYPES = %w[customer_merge administrative account_consolidation].freeze

  belongs_to :from_account, class_name: "StoredValueAccount"
  belongs_to :to_account, class_name: "StoredValueAccount"
  belongs_to :source_customer, class_name: "Customer", optional: true
  belongs_to :survivor_customer, class_name: "Customer", optional: true
  belongs_to :performed_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :stored_value_operation, optional: true
  belongs_to :reversal_of, class_name: "StoredValueTransfer", optional: true
  belongs_to :merge_idempotency_operation, class_name: "IdempotencyOperation", optional: true
  has_one :reversed_by, class_name: "StoredValueTransfer", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception

  validates :transfer_type, :amount_cents, :posted_at, presence: true
  validates :transfer_type, inclusion: { in: TRANSFER_TYPES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def readonly?
    super || persisted?
  end
end
