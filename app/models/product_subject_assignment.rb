# frozen_string_literal: true

class ProductSubjectAssignment < ApplicationRecord
  belongs_to :product
  belongs_to :subject_heading
  belongs_to :subject_scheme

  attribute :primary, :boolean, default: false

  before_validation :copy_scheme

  validates :subject_heading_id, uniqueness: { scope: :product_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :heading_assignable_on_create
  validate :scheme_matches_heading
  validate :one_primary_per_scheme

  private

  def copy_scheme
    self.subject_scheme_id ||= subject_heading&.subject_scheme_id
  end

  def scheme_matches_heading
    return if subject_heading.blank? || subject_scheme_id.blank?
    return if subject_scheme_id == subject_heading.subject_scheme_id

    errors.add(:subject_scheme_id, "must match the heading's scheme")
  end

  def heading_assignable_on_create
    return unless new_record?
    return if subject_heading.blank? || subject_heading.assignable?

    errors.add(:subject_heading_id, "must be an active heading")
  end

  def one_primary_per_scheme
    return unless primary?
    return if product_id.blank? || subject_scheme_id.blank?

    scope = ProductSubjectAssignment.where(product_id: product_id, subject_scheme_id: subject_scheme_id, primary: true)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:primary, "already exists for this scheme") if scope.exists?
  end
end
