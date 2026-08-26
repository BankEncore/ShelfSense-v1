# frozen_string_literal: true

class CashTransfer < ApplicationRecord
  TRANSFER_TYPES = %w[opening_float drop replenishment session_close deposit].freeze

  belongs_to :cash_operation
  belongs_to :source_pos_session, class_name: "PosSession", optional: true
  belongs_to :source_cash_location, class_name: "CashLocation", optional: true
  belongs_to :destination_pos_session, class_name: "PosSession", optional: true
  belongs_to :destination_cash_location, class_name: "CashLocation", optional: true

  validates :transfer_type, presence: true, inclusion: { in: TRANSFER_TYPES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def readonly?
    super || persisted?
  end
end
