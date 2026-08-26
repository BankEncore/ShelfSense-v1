# frozen_string_literal: true

class CashCountDenominationLine < ApplicationRecord
  belongs_to :cash_count

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :denomination_cents, numericality: { only_integer: true, greater_than: 0 }

  def readonly?
    super || persisted?
  end
end
