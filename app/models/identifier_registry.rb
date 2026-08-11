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
    owner_count = [ product_id, product_variant_id ].count(&:present?)
    errors.add(:base, "registry rows may have at most one owner") if owner_count > 1

    if active?
      case identifier_kind
      when "product_primary"
        errors.add(:product_id, "is required for active product_primary rows") if product_id.blank?
        errors.add(:product_variant_id, "must be blank for product_primary rows") if product_variant_id.present?
      when "variant_sku", "variant_industry"
        errors.add(:product_variant_id, "is required for active #{identifier_kind} rows") if product_variant_id.blank?
        errors.add(:product_id, "must be blank for #{identifier_kind} rows") if product_id.present?
      end
    elsif owner_count.zero? && retired_at.blank?
      errors.add(:retired_at, "must be set when unowned")
    end
  end
end
