# frozen_string_literal: true

class Product < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze

  attr_accessor :identifier_writes_enabled

  belongs_to :merchandise_category, optional: true
  has_many :product_variants, dependent: :restrict_with_exception
  has_many :identifier_registry_entries, class_name: "IdentifierRegistry", dependent: :nullify

  validates :name, :primary_identifier, :status, presence: true
  validates :primary_identifier, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :list_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :validate_changed_category
  validate :primary_identifier_write_rules
  after_save { self.identifier_writes_enabled = false }

  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }

  def draft?
    status == "draft"
  end

  def active_status?
    status == "active"
  end

  private

  def validate_changed_category
    return unless merchandise_category_id_changed?
    return if merchandise_category.blank?

    errors.add(:merchandise_category_id, "must be an active category") unless merchandise_category.assignable?
  end

  def primary_identifier_write_rules
    if new_record?
      unless identifier_writes_enabled
        errors.add(:primary_identifier, "must be assigned through Products::Create")
      end
    elsif primary_identifier_changed?
      errors.add(:primary_identifier, "cannot be changed")
    end
  end
end
