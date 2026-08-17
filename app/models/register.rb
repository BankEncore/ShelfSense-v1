# frozen_string_literal: true

class Register < ApplicationRecord
  belongs_to :store
  belongs_to :deactivated_by, class_name: "User", optional: true

  before_validation :normalize_register_number

  validates :register_number, :name, presence: true
  validates :register_number, uniqueness: { scope: :store_id, case_sensitive: false }
  validates :receipt_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :register_number_immutable_after_receipts, on: :update

  scope :active, -> { where(active: true) }

  def admin_label
    "#{register_number} — #{name}"
  end

  private

  def normalize_register_number
    self.register_number = register_number.to_s.strip
  end

  def register_number_immutable_after_receipts
    return unless will_save_change_to_register_number?
    return if receipt_sequence.to_i.zero?

    errors.add(:register_number, "cannot change after a receipt has been issued")
  end
end
