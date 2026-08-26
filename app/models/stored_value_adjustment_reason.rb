# frozen_string_literal: true

class StoredValueAdjustmentReason < ApplicationRecord
  DIRECTIONS = %w[credit debit either].freeze
  ACCOUNT_TYPES = StoredValueAccount::ACCOUNT_TYPES

  validates :code, :name, :allowed_direction, presence: true
  validates :code, uniqueness: { case_sensitive: false }
  validates :allowed_direction, inclusion: { in: DIRECTIONS }
  validates :display_order, numericality: { only_integer: true }
  validate :allowed_account_types_valid
  validate :code_immutable, on: :update

  before_validation :normalize_code

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:display_order, :code) }

  def allows?(direction:, account_type:)
    (allowed_direction == "either" || allowed_direction == direction) &&
      Array(allowed_account_types).include?(account_type)
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase
  end

  def allowed_account_types_valid
    types = Array(allowed_account_types)
    errors.add(:allowed_account_types, "can't be blank") if types.blank?
    extras = types - ACCOUNT_TYPES
    errors.add(:allowed_account_types, "contains invalid types") if extras.any?
  end

  def code_immutable
    errors.add(:code, "cannot change after create") if will_save_change_to_code?
  end
end
