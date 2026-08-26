# frozen_string_literal: true

class StoredValueEntry < ApplicationRecord
  belongs_to :stored_value_operation
  belongs_to :stored_value_account
  belongs_to :reversal_of, class_name: "StoredValueEntry", optional: true
  has_one :reversed_by, class_name: "StoredValueEntry", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception

  validates :entry_sequence, :amount_cents, :balance_after_cents, presence: true
  validates :entry_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :amount_cents, numericality: { only_integer: true, other_than: 0 }
  validates :balance_after_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def readonly?
    super || persisted?
  end
end
