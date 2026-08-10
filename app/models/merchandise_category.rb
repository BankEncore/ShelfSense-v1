# frozen_string_literal: true

class MerchandiseCategory < ApplicationRecord
  belongs_to :parent, class_name: "MerchandiseCategory", optional: true
  belongs_to :default_merchandise_class, class_name: "MerchandiseClass", optional: true
  has_many :children, class_name: "MerchandiseCategory", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_exception

  before_validation :normalize_code

  validates :name, presence: true
  validate :parent_not_self
  validate :no_parent_cycle
  validate :validate_changed_default_class

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def assignable?
    active?
  end

  private

  def normalize_code
    self.code = code.to_s.strip.downcase.tr(" ", "_").presence
  end

  def parent_not_self
    return if parent_id.blank? || id.blank?
    errors.add(:parent_id, "cannot reference itself") if parent_id == id
  end

  def no_parent_cycle
    return if parent.blank?

    seen = Set.new
    current = parent
    while current
      if current.id == id || seen.include?(current.id)
        errors.add(:parent_id, "would create a hierarchy cycle")
        break
      end
      seen << current.id
      current = current.parent
    end
  end

  def validate_changed_default_class
    return unless default_merchandise_class_id_changed?
    return if default_merchandise_class.blank?

    errors.add(:default_merchandise_class_id, "must be an active merchandise class") unless default_merchandise_class.assignable?
  end
end
