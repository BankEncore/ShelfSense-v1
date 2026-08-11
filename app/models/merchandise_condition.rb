# frozen_string_literal: true

class MerchandiseCondition < ApplicationRecord
  include HasMachineCode

  validates :code, :name, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :price_adjustment_bps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  def reactivation_blockers
    []
  end
end
