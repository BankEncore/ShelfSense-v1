# frozen_string_literal: true

class CashDeposit < ApplicationRecord
  belongs_to :store
  belongs_to :prepared_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :cash_count
  belongs_to :cash_operation

  validates :business_date, :deposit_number, presence: true
  validates :total_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :deposit_number, numericality: { only_integer: true, greater_than: 0 }

  def readonly?
    super || persisted?
  end

  def reversed?
    cash_operation.reversed?
  end
end
