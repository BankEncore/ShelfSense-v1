# frozen_string_literal: true

class PosTransaction < ApplicationRecord
  STATUSES = %w[working completed cancelled].freeze

  belongs_to :store
  belongs_to :register
  belongs_to :pos_session
  belongs_to :reporting_period, class_name: "PosReportingPeriod"
  belongs_to :cashier_user, class_name: "User"
  belongs_to :post_void_of, class_name: "PosTransaction", foreign_key: :post_void_of_transaction_id, optional: true
  has_one :post_void, class_name: "PosTransaction", foreign_key: :post_void_of_transaction_id, dependent: :restrict_with_exception
  has_many :pos_transaction_lines, -> { order(:line_number) }, dependent: :destroy
  has_many :pos_controlled_actions, dependent: :destroy
  has_many :pos_tenders, -> { ordered }, dependent: :destroy
  has_many :pos_operations, dependent: :restrict_with_exception

  validates :status, :currency_code, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency_code, length: { is: 3 }
  validate :context_consistency

  scope :working, -> { where(status: "working") }
  scope :completed, -> { where(status: "completed") }

  def working?
    status == "working"
  end

  def completed?
    status == "completed"
  end

  def cancelled?
    status == "cancelled"
  end

  def sale_total_cents
    subtotal_cents - discount_cents + tax_cents
  end

  def post_void?
    post_void_of_transaction_id.present?
  end

  def even_exchange?
    signed_net_cents.to_i.zero? &&
      pos_transaction_lines.any?(&:sale?) &&
      pos_transaction_lines.any?(&:return?)
  end

  def commercially_immutable?
    persisted? && %w[completed cancelled].include?(attribute_in_database("status"))
  end

  def readonly?
    super || commercially_immutable?
  end

  def amount_due_cents
    total_cents
  end

  private

  def context_consistency
    return if pos_session.blank? || register.blank? || reporting_period.blank?

    errors.add(:register_id, "must match the session register") if register_id != pos_session.register_id
    errors.add(:pos_session_id, "must be open") if working? && !pos_session.open?
    errors.add(:reporting_period_id, "must match the session reporting period") if reporting_period_id != pos_session.reporting_period_id
    errors.add(:store_id, "must match the register's store") if store_id != register.store_id
  end
end
