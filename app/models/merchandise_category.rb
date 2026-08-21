# frozen_string_literal: true

class MerchandiseCategory < ApplicationRecord
  include HasMachineCode

  belongs_to :parent, class_name: "MerchandiseCategory", optional: true
  belongs_to :default_standard_merchandise_class, class_name: "MerchandiseClass", optional: true
  belongs_to :default_used_merchandise_class, class_name: "MerchandiseClass", optional: true
  has_many :children, class_name: "MerchandiseCategory", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :code, uniqueness: true, allow_nil: true, format: { with: Codes::Normalizer::FORMAT, allow_nil: true }
  validate :parent_not_self
  validate :no_parent_cycle
  validate :validate_changed_default_classes

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:display_order, :name) }

  def self.machine_code_optional?
    true
  end

  def assignable?
    active?
  end

  def admin_label
    name
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

  # Depth-first walk for selects/indexes: children appear under their parent,
  # each level sorted by display_order then name.
  def self.hierarchical_entries(records)
    list = Array(records)
    by_parent = list.group_by(&:parent_id)
    ids = list.map(&:id).to_set

    sort_level = lambda do |items|
      items.sort_by { |item| [ item.display_order.to_i, item.name.to_s.downcase ] }
    end

    walk = lambda do |parent_id, depth|
      children = Array(by_parent[parent_id])
      sort_level.call(children).flat_map do |category|
        [ [ category, depth ] ] + walk.call(category.id, depth + 1)
      end
    end

    roots = list.select { |category| category.parent_id.nil? || !ids.include?(category.parent_id) }
    sort_level.call(roots).flat_map { |category| [ [ category, 0 ] ] + walk.call(category.id, 1) }
  end

  def self.options_for_select(records)
    hierarchical_entries(records).map do |category, depth|
      label = depth.positive? ? "#{"\u00A0\u00A0" * depth}#{category.admin_label}" : category.admin_label
      [ label, category.id ]
    end
  end

  def reactivation_blockers
    blockers = []
    blockers << "parent category must be active" if parent.present? && !parent.active?
    if default_standard_merchandise_class.present? && !default_standard_merchandise_class.active?
      blockers << "default standard merchandise class must be active"
    end
    if default_used_merchandise_class.present? && !default_used_merchandise_class.active?
      blockers << "default used merchandise class must be active"
    end
    blockers
  end

  private

  def prepare_machine_code
    if new_record?
      if code.blank?
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

  def validate_changed_default_classes
    if default_standard_merchandise_class_id_changed? && default_standard_merchandise_class.present?
      unless default_standard_merchandise_class.assignable?
        errors.add(:default_standard_merchandise_class_id, "must be an active merchandise class")
      end
    end

    if default_used_merchandise_class_id_changed? && default_used_merchandise_class.present?
      unless default_used_merchandise_class.assignable?
        errors.add(:default_used_merchandise_class_id, "must be an active merchandise class")
      end
      if default_used_merchandise_class.assignable? && !default_used_merchandise_class.used_merchandise_allowed?
        errors.add(:default_used_merchandise_class_id, "must allow used merchandise")
      end
    end
  end
end
