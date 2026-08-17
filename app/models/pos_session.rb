# frozen_string_literal: true

class PosSession < ApplicationRecord
  STATUSES = %w[open closed].freeze

  belongs_to :store
  belongs_to :register
  belongs_to :reporting_period, class_name: "PosReportingPeriod"
  belongs_to :cashier_user, class_name: "User"
  has_many :pos_transactions, dependent: :restrict_with_exception

  validates :status, :opened_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :opening_float_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :closing_expected_cash_cents, :closing_count_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :closing_variance_cents, numericality: { only_integer: true }, allow_nil: true
  validate :context_matches_period_and_register
  validate :closing_snapshots_match_status
  validate :closing_variance_matches_count_and_expected

  scope :open, -> { where(status: "open") }
  scope :closed, -> { where(status: "closed") }

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def readonly?
    super || (persisted? && attribute_in_database("status") == "closed")
  end

  private

  def context_matches_period_and_register
    return if register.blank? || reporting_period.blank?

    errors.add(:register_id, "must match the reporting period register") if register_id != reporting_period.register_id
    errors.add(:store_id, "must match the register's store") if store_id != register.store_id
  end

  def closing_snapshots_match_status
    snapshots = [ closing_expected_cash_cents, closing_count_cents, closing_variance_cents ]
    if open?
      errors.add(:base, "closing snapshots must be blank while the session is open") if snapshots.any?
    elsif closed?
      errors.add(:base, "closing snapshots are required when the session is closed") if snapshots.any?(&:nil?)
    end
  end

  def closing_variance_matches_count_and_expected
    return if closing_variance_cents.nil? || closing_count_cents.nil? || closing_expected_cash_cents.nil?
    return if closing_variance_cents == closing_count_cents - closing_expected_cash_cents

    errors.add(:closing_variance_cents, "must equal closing count minus expected cash")
  end
end
