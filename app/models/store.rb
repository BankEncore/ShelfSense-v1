# frozen_string_literal: true

class Store < ApplicationRecord
  belongs_to :deactivated_by, class_name: "User", optional: true
  has_many :registers, dependent: :restrict_with_exception
  has_many :store_taxes, dependent: :restrict_with_exception
  has_many :pos_reporting_periods, dependent: :restrict_with_exception
  has_many :pos_sessions, dependent: :restrict_with_exception
  has_many :pos_transactions, dependent: :restrict_with_exception
  has_many :role_assignments, dependent: :restrict_with_exception

  before_validation :normalize_codes

  validates :store_number, :code, :name, :country_code, :timezone, presence: true
  validates :country_code, length: { is: 2 }
  validates :store_number, numericality: { only_integer: true, greater_than: 0 }
  validates :store_number, uniqueness: true
  validates :code, uniqueness: { case_sensitive: false }
  validate :store_number_immutable_after_receipts, on: :update
  validate :cannot_deactivate_with_open_pos_context, if: :deactivating?

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:name) }

  def admin_label
    name
  end

  def self.options_for_select(records = admin_ordered)
    Array(records).map { |store| [ store.admin_label, store.id ] }
  end

  def store_number_locked?
    pos_transactions.completed.exists? || registers.where("receipt_sequence > 0").exists?
  end

  private

  def normalize_codes
    self.code = code.to_s.strip.downcase
    self.country_code = country_code.to_s.strip.upcase
  end

  def store_number_immutable_after_receipts
    return unless will_save_change_to_store_number?
    return unless store_number_locked?

    errors.add(:store_number, "cannot change after a receipt has been issued")
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
