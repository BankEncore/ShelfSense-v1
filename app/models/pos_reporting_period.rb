# frozen_string_literal: true

class PosReportingPeriod < ApplicationRecord
  STATUSES = %w[open finalized].freeze

  belongs_to :store
  belongs_to :register
  has_many :pos_sessions, foreign_key: :reporting_period_id, dependent: :restrict_with_exception
  has_many :pos_transactions, foreign_key: :reporting_period_id, dependent: :restrict_with_exception

  validates :status, :opened_at, :business_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :store_matches_register

  scope :open, -> { where(status: "open") }

  def open?
    status == "open"
  end

  private

  def store_matches_register
    return if store_id.blank? || register.blank?
    return if store_id == register.store_id

    errors.add(:store_id, "must match the register's store")
  end
end
