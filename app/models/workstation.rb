# frozen_string_literal: true

class Workstation < ApplicationRecord
  belongs_to :store
  belongs_to :deactivated_by, class_name: "User", optional: true

  before_validation :normalize_code

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :store_id, case_sensitive: false }
  validates :receipt_sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end
end
