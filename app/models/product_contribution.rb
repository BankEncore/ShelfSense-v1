# frozen_string_literal: true

class ProductContribution < ApplicationRecord
  ROLES = %w[author editor illustrator translator photographer narrator other].freeze

  belongs_to :product

  before_validation :normalize_display_name

  validates :display_name, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :display_name, uniqueness: { scope: [ :product_id, :role ] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def normalize_display_name
    self.display_name = display_name.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, " ").presence
  end
end
