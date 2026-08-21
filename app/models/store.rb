# frozen_string_literal: true

class Store < ApplicationRecord
  belongs_to :deactivated_by, class_name: "User", optional: true
  has_many :registers, dependent: :restrict_with_exception
  has_many :store_taxes, dependent: :restrict_with_exception
  has_many :pos_reporting_periods, dependent: :restrict_with_exception
  has_many :pos_sessions, dependent: :restrict_with_exception
  has_many :pos_transactions, dependent: :restrict_with_exception
  has_many :role_assignments, dependent: :restrict_with_exception

  RECEIPT_MODES = %w[inherit custom none].freeze
  RECEIPT_MESSAGE_LIMIT = 500

  before_validation :normalize_codes
  before_validation :normalize_receipt_messages

  validates :store_number, :code, :name, :country_code, :timezone, presence: true
  validates :legal_name, presence: true, if: :active?
  validates :receipt_header_mode, :receipt_footer_mode, inclusion: { in: RECEIPT_MODES }
  validates :receipt_header, :receipt_footer, length: { maximum: RECEIPT_MESSAGE_LIMIT }
  validate :custom_receipt_text_present
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

  def effective_receipt_header
    Pos::ReceiptMessages.header(self)
  end

  def effective_receipt_footer
    Pos::ReceiptMessages.footer(self)
  end

  private

  def normalize_codes
    self.code = code.to_s.strip.downcase
    self.country_code = country_code.to_s.strip.upcase
  end

  def normalize_receipt_messages
    self.receipt_header = receipt_header&.strip
    self.receipt_footer = receipt_footer&.strip
    self.legal_name = legal_name&.strip
  end

  def custom_receipt_text_present
    if receipt_header_mode == "custom" && receipt_header.blank?
      errors.add(:receipt_header, "is required when the header mode is custom")
    end
    if receipt_footer_mode == "custom" && receipt_footer.blank?
      errors.add(:receipt_footer, "is required when the footer mode is custom")
    end
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
