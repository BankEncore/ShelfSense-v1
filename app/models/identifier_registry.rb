# frozen_string_literal: true

class IdentifierRegistry < ApplicationRecord
  self.table_name = "identifier_registry"

  KINDS = %w[product_primary variant_sku variant_industry].freeze

  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  validates :value, :identifier_kind, presence: true
  validates :value, uniqueness: true
  validates :identifier_kind, inclusion: { in: KINDS }
  validate :ownership_rules

  scope :active, -> { where(retired_at: nil) }
  scope :retired, -> { where.not(retired_at: nil) }

  def active?
    retired_at.nil?
  end

  private

  def ownership_rules
    owners = [ product_id, product_variant_id ].compact
    if active?
      errors.add(:base, "active registry rows require exactly one owner") unless owners.size == 1
    elsif owners.empty? && retired_at.blank?
      errors.add(:retired_at, "must be set when unowned")
    end
  end
end
