# frozen_string_literal: true

class CashPaidIn < ApplicationRecord
  belongs_to :pos_session
  belongs_to :cash_operation

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :reason_code, :reason_name_snapshot, presence: true

  def readonly?
    super || persisted?
  end
end
