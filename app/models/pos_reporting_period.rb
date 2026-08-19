# frozen_string_literal: true

class PosReportingPeriod < ApplicationRecord
  STATUSES = %w[open finalized].freeze
  FINALIZED_SNAPSHOT_ATTRIBUTES = %w[
    finalized_transaction_count
    finalized_subtotal_cents
    finalized_tax_cents
    finalized_total_cents
    finalized_cash_payment_cents
    finalized_session_count
    finalized_opening_float_cents_sum
    finalized_closing_expected_cash_cents_sum
    finalized_closing_count_cents_sum
    finalized_closing_variance_cents_sum
    finalized_by_user_id
  ].freeze

  belongs_to :store
  belongs_to :register
  belongs_to :finalized_by, class_name: "User", foreign_key: :finalized_by_user_id, optional: true
  has_many :pos_sessions, foreign_key: :reporting_period_id, dependent: :restrict_with_exception
  has_many :pos_transactions, foreign_key: :reporting_period_id, dependent: :restrict_with_exception

  validates :status, :opened_at, :business_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :finalized_transaction_count, :finalized_session_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :finalized_subtotal_cents, :finalized_tax_cents, :finalized_total_cents,
            :finalized_cash_payment_cents, :finalized_opening_float_cents_sum,
            :finalized_closing_count_cents_sum,
            :finalized_card_payment_cents, :finalized_check_payment_cents, :finalized_other_payment_cents,
            :finalized_discount_cents, :finalized_return_subtotal_cents, :finalized_return_discount_cents,
            :finalized_return_tax_cents, :finalized_return_total_cents, :finalized_cash_refund_cents,
            :finalized_card_refund_cents, :finalized_check_refund_cents, :finalized_other_refund_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :finalized_closing_expected_cash_cents_sum, :finalized_closing_variance_cents_sum, :finalized_net_cents,
            numericality: { only_integer: true }, allow_nil: true
  validate :store_matches_register
  validate :finalized_snapshots_match_status
  validate :category_snapshots_blank_while_open
  validate :finalized_variance_matches_count_and_expected_sums

  scope :open, -> { where(status: "open") }
  scope :finalized, -> { where(status: "finalized") }

  def open?
    status == "open"
  end

  def finalized?
    status == "finalized"
  end

  def readonly?
    super || (persisted? && attribute_in_database("status") == "finalized")
  end

  private

  def store_matches_register
    return if store_id.blank? || register.blank?
    return if store_id == register.store_id

    errors.add(:store_id, "must match the register's store")
  end

  def category_snapshots_blank_while_open
    return unless open?

    additive = %w[
      finalized_card_payment_cents finalized_check_payment_cents finalized_other_payment_cents
      finalized_discount_cents finalized_return_subtotal_cents finalized_return_discount_cents
      finalized_return_tax_cents finalized_return_total_cents finalized_net_cents
      finalized_cash_refund_cents finalized_card_refund_cents finalized_check_refund_cents
      finalized_other_refund_cents
    ]
    if additive.any? { |attribute| !self[attribute].nil? }
      errors.add(:base, "tender category snapshots must be blank while the period is open")
    end
  end

  def finalized_snapshots_match_status
    snapshots = FINALIZED_SNAPSHOT_ATTRIBUTES.map { |attribute| self[attribute] }
    if open?
      errors.add(:base, "finalized snapshots must be blank while the period is open") if snapshots.any?
    elsif finalized?
      errors.add(:base, "finalized snapshots are required when the period is finalized") if snapshots.any?(&:nil?)
    end
  end

  def finalized_variance_matches_count_and_expected_sums
    return if finalized_closing_variance_cents_sum.nil? ||
              finalized_closing_count_cents_sum.nil? ||
              finalized_closing_expected_cash_cents_sum.nil?
    return if finalized_closing_variance_cents_sum ==
              finalized_closing_count_cents_sum - finalized_closing_expected_cash_cents_sum

    errors.add(:finalized_closing_variance_cents_sum, "must equal closing count sum minus expected cash sum")
  end
end
