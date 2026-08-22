# frozen_string_literal: true

class SupplierVariantSource < ApplicationRecord
  PRICING_METHODS = %w[discount_from_list direct_unit_cost].freeze

  belongs_to :supplier
  belongs_to :product_variant
  has_many :store_supplier_source_preferences, dependent: :restrict_with_exception

  before_validation :normalize_supplier_item_number
  before_validation :clear_inapplicable_pricing_fields

  validates :pricing_method, presence: true, inclusion: { in: PRICING_METHODS }
  validates :supplier_item_number,
            uniqueness: { scope: :supplier_id },
            allow_nil: true
  validates :supplier_list_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :discount_basis_points,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
            allow_nil: true
  validates :expected_unit_cost_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validate :variant_must_be_standard_inventory_bearing
  validate :pricing_method_field_exclusivity
  validate :at_most_one_organization_preferred_active_per_variant

  scope :active, -> { where(active: true) }
  scope :organization_preferred, -> { where(organization_preferred: true) }
  scope :admin_ordered, -> { order(:created_at) }

  def admin_label
    parts = [ supplier&.admin_label, product_variant&.sku ].compact
    parts << supplier_item_number if supplier_item_number.present?
    parts.join(" · ")
  end

  def reactivation_blockers
    []
  end

  def derived_expected_unit_cost_cents
    case pricing_method
    when "direct_unit_cost"
      expected_unit_cost_cents
    when "discount_from_list"
      return nil if supplier_list_price_cents.nil? || discount_basis_points.nil?

      remaining_bps = 10_000 - discount_basis_points.to_i
      (BigDecimal(supplier_list_price_cents.to_s) * BigDecimal(remaining_bps.to_s) / 10_000)
        .round(0, half: :up).to_i
    end
  end

  private

  def normalize_supplier_item_number
    self.supplier_item_number = supplier_item_number.to_s.strip.presence
  end

  def clear_inapplicable_pricing_fields
    case pricing_method
    when "discount_from_list"
      self.expected_unit_cost_cents = nil
    when "direct_unit_cost"
      self.supplier_list_price_cents = nil
      self.discount_basis_points = nil
    end
  end

  def variant_must_be_standard_inventory_bearing
    return if product_variant.blank?

    unless product_variant.standard?
      errors.add(:product_variant_id, "must be a Standard variant")
      return
    end

    unless product_variant.inventory_mode == "inventory"
      errors.add(:product_variant_id, "must be inventory-bearing")
    end
  end

  def pricing_method_field_exclusivity
    case pricing_method
    when "discount_from_list"
      errors.add(:supplier_list_price_cents, "is required for discount from list") if supplier_list_price_cents.nil?
      errors.add(:discount_basis_points, "is required for discount from list") if discount_basis_points.nil?
      errors.add(:expected_unit_cost_cents, "must be blank for discount from list") if expected_unit_cost_cents.present?
    when "direct_unit_cost"
      errors.add(:expected_unit_cost_cents, "is required for direct unit cost") if expected_unit_cost_cents.nil?
      errors.add(:supplier_list_price_cents, "must be blank for direct unit cost") if supplier_list_price_cents.present?
      errors.add(:discount_basis_points, "must be blank for direct unit cost") if discount_basis_points.present?
    end
  end

  def at_most_one_organization_preferred_active_per_variant
    return unless organization_preferred? && active?
    return if product_variant_id.blank?

    conflict = self.class.active.organization_preferred
      .where(product_variant_id: product_variant_id)
      .where.not(id: id)
      .exists?
    return unless conflict

    errors.add(:organization_preferred, "at most one active organization-preferred source is allowed per variant")
  end
end
