# frozen_string_literal: true

class Product < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze
  LOOKUP_CODE_MAX_LENGTH = 64
  LOOKUP_CODE_FORMAT = %r{\A[A-Z0-9._/-]+\z}
  BIBLIOGRAPHIC_FIELD_NAMES = Bibliographic::FieldSources::KEYS.freeze

  attr_accessor :identifier_writes_enabled, :contribution_rows, :subject_rows

  attribute :release_date_approximate, :boolean, default: false

  belongs_to :merchandise_category, optional: true
  belongs_to :product_form, optional: true
  has_many :product_variants, dependent: :restrict_with_exception
  has_many :product_contributions, -> { order(:position, :id) }, dependent: :destroy
  has_many :product_subject_assignments, -> { order(:position, :id) }, dependent: :destroy
  has_many :subject_headings, through: :product_subject_assignments
  has_many :identifier_registry_entries, class_name: "IdentifierRegistry", dependent: :nullify
  has_one_attached :cover_image

  before_validation :normalize_lookup_code
  before_validation :normalize_variant_option_labels

  validates :name, :primary_identifier, :status, presence: true
  validates :primary_identifier, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :industry_identifier, uniqueness: true, allow_nil: true, format: { with: /\A\d{13}\z/ }
  validates :lookup_code,
            length: { maximum: LOOKUP_CODE_MAX_LENGTH },
            format: { with: LOOKUP_CODE_FORMAT, message: "may contain only A-Z, 0-9, period, underscore, slash, and hyphen" },
            allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :list_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :page_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :series_position, numericality: { greater_than_or_equal_to: -99_999.999, less_than_or_equal_to: 99_999.999 }, allow_nil: true
  validate :validate_changed_category
  validate :validate_assignable_product_form
  validate :lookup_code_not_gift_card_shape
  validate :identifier_write_rules
  validate :validate_field_sources
  validate :validate_variant_option_labels
  validate :validate_variant_option_structure, on: :update
  after_save { self.identifier_writes_enabled = false }

  def attributed?
    variant_option_name_1.to_s.strip.present?
  end

  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }

  # Lookup codes are intentionally nonunique: shared codes require POS product selection.
  def self.matching_lookup_code(raw)
    canonical = self.canonical_lookup_code(raw)
    return none if canonical.blank?

    where(lookup_code: canonical)
  end

  def self.canonical_lookup_code(raw)
    value = raw.to_s.strip.upcase
    value.presence
  end

  def draft?
    status == "draft"
  end

  def active_status?
    status == "active"
  end

  def brand_name_label
    case product_form&.code
    when "CD", "CM", "AU" then "Label"
    when "HC", "PB", "TP", "MM", "BB", "EB", "LB", "TC", "SP", "CB", "RB", "LL", "LT", "IL", "VB", "PO", "BA"
      "Publisher"
    when nil then "Publisher / brand / manufacturer"
    else "Brand / manufacturer"
    end
  end

  private

  def normalize_lookup_code
    self.lookup_code = self.class.canonical_lookup_code(lookup_code)
  end

  def normalize_variant_option_labels
    self.variant_option_name_1 = ProductVariants::NameComposer.trim_display(variant_option_name_1)
    self.variant_option_name_2 = ProductVariants::NameComposer.trim_display(variant_option_name_2)
  end

  def validate_variant_option_labels
    if variant_option_name_2.present? && variant_option_name_1.blank?
      errors.add(:variant_option_name_2, "requires Attribute 1")
    end

    n1 = ProductVariants::NameComposer.normalize_label(variant_option_name_1)
    n2 = ProductVariants::NameComposer.normalize_label(variant_option_name_2)
    return if n1.blank? || n2.blank?
    return unless n1 == n2

    errors.add(:variant_option_name_2, "must differ from Attribute 1")
  end

  def validate_variant_option_structure
    return unless product_variants.exists?

    was1 = ProductVariants::NameComposer.trim_display(attribute_in_database(:variant_option_name_1)).present?
    was2 = ProductVariants::NameComposer.trim_display(attribute_in_database(:variant_option_name_2)).present?
    now1 = variant_option_name_1.present?
    now2 = variant_option_name_2.present?
    return if was1 == now1 && was2 == now2

    errors.add(:base, "cannot add or remove variant attributes after variants exist")
  end

  def validate_changed_category
    return unless merchandise_category_id_changed?
    return if merchandise_category.blank?

    errors.add(:merchandise_category_id, "must be an active category") unless merchandise_category.assignable?
  end

  def validate_assignable_product_form
    return unless will_save_change_to_product_form_id?
    return if product_form.blank?

    errors.add(:product_form_id, "must be an active product form") unless product_form.assignable?
  end

  def validate_field_sources
    Bibliographic::FieldSources.validate!(bibliographic_field_sources)
  rescue Bibliographic::FieldSources::Invalid => e
    errors.add(:bibliographic_field_sources, e.message)
  end

  def identifier_write_rules
    if new_record?
      unless identifier_writes_enabled
        errors.add(:primary_identifier, "must be assigned through Products::Create")
      end
      return
    end

    errors.add(:primary_identifier, "cannot be changed") if primary_identifier_changed?

    if industry_identifier_changed? && !identifier_writes_enabled
      errors.add(:industry_identifier, "must be changed through Identifiers::AssignProductIndustry")
    end
  end

  def lookup_code_not_gift_card_shape
    return if lookup_code.blank?
    return unless GiftCardProgram.table_exists?
    return unless GiftCards::Number.matches_active_program?(lookup_code)

    errors.add(:lookup_code, "matches an active gift-card number shape")
  end
end
