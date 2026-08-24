# frozen_string_literal: true

class SubjectScheme < ApplicationRecord
  has_many :subject_headings, dependent: :restrict_with_exception
  has_many :product_subject_assignments, dependent: :restrict_with_exception

  before_validation :normalize_key, on: :create

  validates :key, :name, presence: true
  validates :key, uniqueness: true, format: { with: /\A[a-z0-9]+(?:_[a-z0-9]+)*\z/ }
  validate :key_immutable_after_create

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:name) }

  def assignable?
    active?
  end

  def admin_label
    name
  end

  def reactivation_blockers
    []
  end

  private

  def normalize_key
    self.key = key.to_s.strip.downcase.presence
  end

  def key_immutable_after_create
    return if new_record?
    return unless will_save_change_to_key?

    errors.add(:key, "cannot be changed after creation")
  end
end
