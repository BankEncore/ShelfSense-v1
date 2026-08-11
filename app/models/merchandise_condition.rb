# frozen_string_literal: true

class MerchandiseCondition < ApplicationRecord
  before_validation :normalize_code

  validates :code, :name, presence: true
  validates :code, uniqueness: true
  validates :price_adjustment_bps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase.tr(" ", "_")
  end
end
