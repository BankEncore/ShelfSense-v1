# frozen_string_literal: true

class CashSafeInitialization < ApplicationRecord
  belongs_to :cash_location
  belongs_to :cash_count
  belongs_to :cash_operation

  validates :counted_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def readonly?
    super || persisted?
  end
end
