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
  validate :context_matches_period_and_register

  scope :open, -> { where(status: "open") }

  def open?
    status == "open"
  end

  private

  def context_matches_period_and_register
    return if register.blank? || reporting_period.blank?

    errors.add(:register_id, "must match the reporting period register") if register_id != reporting_period.register_id
    errors.add(:store_id, "must match the register's store") if store_id != register.store_id
  end
end
