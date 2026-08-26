# frozen_string_literal: true

class CashReconciliation < ApplicationRecord
  DIRECTIONS = %w[over short].freeze

  belongs_to :cash_operation
  belongs_to :cash_count
  belongs_to :pos_session, optional: true
  belongs_to :cash_location, optional: true

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :expected_cents, :counted_cents, :variance_cents, presence: true

  def readonly?
    super || persisted?
  end
end
