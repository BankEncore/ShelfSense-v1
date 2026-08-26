# frozen_string_literal: true

class CashPaidOut < ApplicationRecord
  belongs_to :pos_session
  belongs_to :cash_operation
  has_one :pos_controlled_action, dependent: :restrict_with_exception

  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :reason_code, :reason_name_snapshot, presence: true

  def readonly?
    super || persisted?
  end
end
