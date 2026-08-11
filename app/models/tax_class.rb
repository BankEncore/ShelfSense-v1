# frozen_string_literal: true

class TaxClass < ApplicationRecord
  include HasMachineCode

  validates :code, :name, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  def reactivation_blockers
    []
  end
end
