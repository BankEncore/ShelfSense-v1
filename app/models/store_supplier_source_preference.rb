# frozen_string_literal: true

class StoreSupplierSourcePreference < ApplicationRecord
  belongs_to :store
  belongs_to :product_variant
  belongs_to :supplier_variant_source

  validates :store_id, uniqueness: { scope: :product_variant_id }
  validate :source_matches_variant
  validate :source_must_be_standard_inventory_bearing
  validate :source_must_be_active

  private

  def source_matches_variant
    return if supplier_variant_source.blank? || product_variant_id.blank?

    if supplier_variant_source.product_variant_id != product_variant_id
      errors.add(:supplier_variant_source_id, "must belong to the same product variant")
    end
  end

  def source_must_be_standard_inventory_bearing
    variant = product_variant || supplier_variant_source&.product_variant
    return if variant.blank?

    unless variant.standard?
      errors.add(:product_variant_id, "must be a Standard variant")
      return
    end

    unless variant.inventory_mode == "inventory"
      errors.add(:product_variant_id, "must be inventory-bearing")
    end
  end

  def source_must_be_active
    return if supplier_variant_source.blank?
    return if supplier_variant_source.active?

    errors.add(:supplier_variant_source_id, "must be an active source")
  end
end
