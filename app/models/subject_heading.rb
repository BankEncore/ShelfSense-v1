# frozen_string_literal: true

class SubjectHeading < ApplicationRecord
  belongs_to :subject_scheme
  belongs_to :suggested_merchandise_class, class_name: "MerchandiseClass", optional: true
  has_many :product_subject_assignments, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :code, uniqueness: { scope: :subject_scheme_id }, allow_nil: true
  validate :bisac_requires_code
  validate :suggested_class_assignable
  validate :cannot_destroy_if_referenced

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> {
    order(Arel.sql("display_order ASC NULLS LAST"), :code, :name)
  }

  def assignable?
    active?
  end

  def admin_label
    code.present? ? "#{name} (#{code})" : name
  end

  def reactivation_blockers
    []
  end

  def self.search(q)
    return admin_ordered if q.blank?

    pattern = "%#{q.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }}%"
    admin_ordered.where("name ILIKE :q ESCAPE '\\' OR COALESCE(code, '') ILIKE :q ESCAPE '\\'", q: pattern)
  end

  private

  def bisac_requires_code
    return unless subject_scheme&.key == "bisac"
    return if code.present?

    errors.add(:code, "is required for BISAC headings")
  end

  def suggested_class_assignable
    return if suggested_merchandise_class.blank?
    return unless will_save_change_to_suggested_merchandise_class_id?
    return if suggested_merchandise_class.assignable?

    errors.add(:suggested_merchandise_class_id, "must be an active merchandise class")
  end

  def cannot_destroy_if_referenced
    # Deactivation is used instead of deletion when referenced.
  end
end
