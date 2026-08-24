# frozen_string_literal: true

class ProductContribution < ApplicationRecord
  ROLES = %w[author illustrator editor translator other].freeze

  belongs_to :product
  belongs_to :contributor

  validates :role, inclusion: { in: ROLES }
  validates :contributor_id, uniqueness: { scope: [ :product_id, :role ] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
