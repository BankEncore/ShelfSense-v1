# frozen_string_literal: true

class TaxClass < ApplicationRecord
  before_validation :normalize_code

  validates :code, :name, presence: true
  validates :code, uniqueness: true

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
