# frozen_string_literal: true

class StoreTax < ApplicationRecord
  belongs_to :store
  has_many :store_tax_rules, dependent: :destroy

  before_validation :normalize_code

  validates :code, :name, :rate_percent, :calculation_order, presence: true
  validates :code, uniqueness: { scope: :store_id, case_sensitive: false }, format: { with: Codes::Normalizer::FORMAT }
  validates :rate_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :calculation_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :code_immutable_once_referenced, on: :update

  scope :active, -> { where(active: true) }
  scope :calculation_ordered, -> { order(:calculation_order, :code, :id) }

  def admin_label
    "#{name} (#{rate_percent_display}%)"
  end

  def rate_percent_display
    format("%.3f", rate_percent)
  end

  def referenced_by_completed_component?
    return false unless self.class.connection.data_source_exists?("pos_line_tax_components")

    self.class.connection.select_value(
      "SELECT 1 FROM pos_line_tax_components WHERE store_tax_id = #{self.class.connection.quote(id)} LIMIT 1"
    ).present?
  end

  def reactivation_blockers
    []
  end

  private

  def normalize_code
    return if persisted? && !will_save_change_to_code?

    source = code.presence || name
    return if source.blank?

    self.code = Codes::Normalizer.normalize(source)
  end

  def code_immutable_once_referenced
    return unless will_save_change_to_code?
    return unless referenced_by_completed_component?

    errors.add(:code, "cannot be changed after a completed sale has used this tax")
  end
end
