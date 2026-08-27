# frozen_string_literal: true

class CashCount < ApplicationRecord
  PURPOSES = %w[session_open session_close safe_reconciliation deposit safe_initialization].freeze
  STATUSES = %w[discarded accepted].freeze

  belongs_to :pos_session, optional: true
  belongs_to :cash_location, optional: true
  belongs_to :superseded_count, class_name: "CashCount", optional: true
  has_many :cash_count_denomination_lines, dependent: :restrict_with_exception
  has_one :cash_deposit, dependent: :restrict_with_exception

  validates :purpose, presence: true, inclusion: { in: PURPOSES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :superseded_count_id, uniqueness: true, allow_nil: true
  validates :expected_cents_snapshot, :location_lock_version_snapshot, :business_date,
            presence: true, if: :location_snapshot_required?
  validate :superseded_count_is_discarded

  def location_snapshot_required?
    purpose.in?(%w[safe_reconciliation deposit])
  end

  def readonly?
    super || persisted?
  end

  private

  def superseded_count_is_discarded
    return if superseded_count_id.blank?
    return if superseded_count&.status == "discarded"

    errors.add(:superseded_count, "must be a discarded snapshot")
  end
end
