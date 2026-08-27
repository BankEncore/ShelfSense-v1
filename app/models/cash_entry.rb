# frozen_string_literal: true

class CashEntry < ApplicationRecord
  belongs_to :cash_operation
  belongs_to :pos_session, optional: true
  belongs_to :cash_location, optional: true
  belongs_to :reversal_of, class_name: "CashEntry", optional: true
  has_one :reversed_by, class_name: "CashEntry", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception

  validates :entry_sequence, :amount_cents, :balance_after_cents, presence: true
  validates :amount_cents, numericality: { other_than: 0, only_integer: true }
  validates :balance_after_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :exactly_one_target
  validate :target_belongs_to_operation_store

  def readonly?
    super || persisted?
  end

  private

  def exactly_one_target
    if pos_session_id.present? == cash_location_id.present?
      errors.add(:base, "exactly one of pos_session_id or cash_location_id is required")
    end
  end

  def target_belongs_to_operation_store
    return if cash_operation.blank?

    store_id = cash_operation.store_id
    if cash_location && cash_location.store_id != store_id
      errors.add(:cash_location_id, "must belong to the operation store")
    end
    if pos_session && pos_session.store_id != store_id
      errors.add(:pos_session_id, "must belong to the operation store")
    end
  end
end
