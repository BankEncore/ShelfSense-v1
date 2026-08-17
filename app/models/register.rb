# frozen_string_literal: true

class Register < ApplicationRecord
  belongs_to :store
  belongs_to :deactivated_by, class_name: "User", optional: true
  has_many :pos_reporting_periods, dependent: :restrict_with_exception
  has_many :pos_sessions, dependent: :restrict_with_exception
  has_many :pos_transactions, dependent: :restrict_with_exception

  validates :register_number, :name, presence: true
  validates :register_number, numericality: { only_integer: true, greater_than: 0 }
  validates :register_number, uniqueness: { scope: :store_id }
  validates :receipt_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :register_number_immutable_after_receipts, on: :update
  validate :receipt_sequence_never_decreases, on: :update
  validate :cannot_deactivate_with_open_pos_context, if: :deactivating?

  scope :active, -> { where(active: true) }

  def admin_label
    "#{register_number} — #{name}"
  end

  private

  def receipt_history?
    persisted? && attribute_in_database("receipt_sequence").to_i.positive?
  end

  def register_number_immutable_after_receipts
    return unless will_save_change_to_register_number?
    return unless receipt_history?

    errors.add(:register_number, "cannot change after a receipt has been issued")
  end

  def receipt_sequence_never_decreases
    return unless will_save_change_to_receipt_sequence?
    return if receipt_sequence.to_i >= attribute_in_database("receipt_sequence").to_i

    errors.add(:receipt_sequence, "cannot decrease")
  end

  def deactivating?
    will_save_change_to_active? && !active
  end

  def cannot_deactivate_with_open_pos_context
    if pos_reporting_periods.open.exists?
      errors.add(:base, "cannot deactivate while an open reporting period exists")
    elsif pos_sessions.open.exists?
      errors.add(:base, "cannot deactivate while an open session exists")
    elsif pos_transactions.working.exists?
      errors.add(:base, "cannot deactivate while a working transaction exists")
    end
  end
end
