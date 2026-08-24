# frozen_string_literal: true

class Product < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze
  LOOKUP_CODE_MAX_LENGTH = 64
  LOOKUP_CODE_FORMAT = %r{\A[A-Z0-9._/-]+\z}
  BIBLIOGRAPHIC_FIELD_NAMES = %w[
    name subtitle description list_price_cents imprint edition binding language_code
    page_count series_name series_position cover_image_url publication_year release_date
    publisher_id contributions
  ].freeze

  attr_accessor :identifier_writes_enabled, :publisher_name, :contribution_rows

  belongs_to :merchandise_category, optional: true
  belongs_to :publisher, optional: true
  has_many :product_variants, dependent: :restrict_with_exception
  has_many :product_contributions, -> { order(:position, :id) }, dependent: :destroy
  has_many :contributors, through: :product_contributions
  has_many :identifier_registry_entries, class_name: "IdentifierRegistry", dependent: :nullify

  before_validation :normalize_lookup_code

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
  validates :publication_year, numericality: { only_integer: true, greater_than_or_equal_to: 1400, less_than_or_equal_to: 2100 }, allow_nil: true
  validate :validate_changed_category
  validate :identifier_write_rules
  after_save { self.identifier_writes_enabled = false }

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

  private

  def normalize_lookup_code
    self.lookup_code = self.class.canonical_lookup_code(lookup_code)
  end

  def validate_changed_category
    return unless merchandise_category_id_changed?
    return if merchandise_category.blank?

    errors.add(:merchandise_category_id, "must be an active category") unless merchandise_category.assignable?
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
end
