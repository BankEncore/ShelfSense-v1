# frozen_string_literal: true

class MerchandiseCondition < ApplicationRecord
  DEPARTMENT_BASES = %w[standard used].freeze

  before_validation :normalize_code

  validates :code, :name, :department_basis, presence: true
  validates :code, uniqueness: true
  validates :department_basis, inclusion: { in: DEPARTMENT_BASES }
  validates :price_adjustment_bps, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  def used_basis?
    department_basis == "used"
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase.tr(" ", "_")
  end
end
