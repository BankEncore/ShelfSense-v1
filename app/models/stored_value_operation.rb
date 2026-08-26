# frozen_string_literal: true

class StoredValueOperation < ApplicationRecord
  OPERATION_TYPES = %w[issue activate reload redeem refund cash_out transfer adjust reverse].freeze

  belongs_to :store
  belongs_to :performed_by, class_name: "User"
  belongs_to :pos_session, optional: true
  belongs_to :idempotency_operation
  belongs_to :reversal_of, class_name: "StoredValueOperation", optional: true
  has_one :reversed_by, class_name: "StoredValueOperation", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception
  has_many :stored_value_entries, -> { order(:entry_sequence) }, dependent: :restrict_with_exception
  has_one :stored_value_adjustment, dependent: :restrict_with_exception
  has_one :stored_value_transfer, dependent: :restrict_with_exception

  validates :operation_type, :business_date, :occurred_at, presence: true
  validates :operation_type, inclusion: { in: OPERATION_TYPES }

  def readonly?
    super || persisted?
  end

  def reverse?
    operation_type == "reverse"
  end

  def reversed?
    reversed_by.present?
  end
end
