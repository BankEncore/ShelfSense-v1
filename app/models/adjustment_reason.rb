# frozen_string_literal: true

class AdjustmentReason < ApplicationRecord
  include UuidV7PrimaryKey

  DIRECTIONS = %w[increase decrease either].freeze

  validates :code, :name, :direction, presence: true
  validates :code, uniqueness: true
  validates :direction, inclusion: { in: DIRECTIONS }

  before_validation :normalize_code

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase.tr(" ", "_") if code.present?
  end
end
