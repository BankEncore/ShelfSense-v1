# frozen_string_literal: true

class MerchandiseCategory < ApplicationRecord
  include HasMachineCode

  belongs_to :parent, class_name: "MerchandiseCategory", optional: true
  belongs_to :default_merchandise_class, class_name: "MerchandiseClass", optional: true
  has_many :children, class_name: "MerchandiseCategory", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :code, uniqueness: true, allow_nil: true, format: { with: Codes::Normalizer::FORMAT, allow_nil: true }
  validate :parent_not_self
  validate :no_parent_cycle
  validate :validate_changed_default_class

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }

  def self.machine_code_optional?
    true
  end

  def assignable?
    active?
  end

  # Root categories return their name; nested categories return "Parent > Child > …".
  def path_label(separator: " > ")
    names = []
    current = self
    seen = Set.new

    while current
      break if seen.include?(current.id)

      seen << current.id
      names.unshift(current.name)
      current = current.parent
    end

    names.join(separator)
  end

  def self.options_for_select(records)
    Array(records).map { |category| [category.path_label, category.id] }
  end

  def reactivation_blockers
    blockers = []
    blockers << "parent category must be active" if parent.present? && !parent.active?
    if default_merchandise_class.present? && !default_merchandise_class.active?
      blockers << "default merchandise class must be active"
    end
    blockers
  end

  private

  def prepare_machine_code
    if new_record?
      if code.blank?
        # Optional: leave blank unless supplied or name is used for generation when code was omitted intentionally.
        # Spec: blank generates from name. Categories generate when name present.
        if name.present?
          self.code = Codes::Normalizer.normalize(name).presence
        end
        return
      end
      self.code = Codes::Normalizer.normalize(code).presence
    end
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
