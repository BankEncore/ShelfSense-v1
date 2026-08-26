# frozen_string_literal: true

class CashCount < ApplicationRecord
  PURPOSES = %w[session_open session_close safe_reconciliation deposit safe_initialization].freeze
  STATUSES = %w[discarded accepted].freeze

  belongs_to :pos_session, optional: true
  belongs_to :cash_location, optional: true
  belongs_to :superseded_count, class_name: "CashCount", optional: true
  has_many :cash_count_denomination_lines, dependent: :restrict_with_exception

  validates :purpose, presence: true, inclusion: { in: PURPOSES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def readonly?
    super || persisted?
  end
end
