# frozen_string_literal: true

class ProductForm < ApplicationRecord
  CODE_FORMAT = /\A[A-Z]{2}\z/

  has_many :products, dependent: :restrict_with_exception

  before_validation :normalize_code, on: :create

  validates :code, presence: true, uniqueness: true, format: { with: CODE_FORMAT }
  validates :name, presence: true
  validates :display_order, presence: true, numericality: { only_integer: true }
  validate :code_immutable_after_create

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:display_order, :name) }

  def assignable?
    active?
  end

  def admin_label
    name
  end

  def reactivation_blockers
    []
  end

  def self.options_for_select(records = assignable.admin_ordered)
    Array(records).map { |form| [ form.admin_label, form.id ] }
  end

  def self.known_code?(code)
    exists?(code: code.to_s.upcase)
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase.presence
  end

  def code_immutable_after_create
    return if new_record?
    return unless will_save_change_to_code?

    errors.add(:code, "cannot be changed after creation")
  end
end
