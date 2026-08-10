# frozen_string_literal: true

class Product < ApplicationRecord
  STATUSES = %w[draft active discontinued].freeze

  belongs_to :merchandise_category, optional: true
  has_many :product_variants, dependent: :restrict_with_exception
  has_many :identifier_registry_entries, class_name: "IdentifierRegistry", dependent: :nullify

  validates :name, :primary_identifier, :status, presence: true
  validates :primary_identifier, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :status, inclusion: { in: STATUSES }
  validates :list_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :validate_changed_category

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
end
