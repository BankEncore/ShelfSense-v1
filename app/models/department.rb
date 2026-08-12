# frozen_string_literal: true

class Department < ApplicationRecord
  include HasMachineCode

  GL_MAPPING_EXPECTATIONS = {
    inventory_asset_gl_account_id: { account_type: "asset", account_category: "inventory" },
    cost_of_goods_sold_gl_account_id: { account_type: "expense", account_category: "cost_of_goods_sold" },
    sales_revenue_gl_account_id: { account_type: "revenue", account_category: "sales" },
    sales_returns_gl_account_id: { account_type: "revenue", account_category: "sales_returns" },
    inventory_shrinkage_gl_account_id: { account_type: "expense", account_category: "inventory_shrinkage" },
    inventory_adjustment_loss_gl_account_id: { account_type: "expense", account_category: "inventory_adjustment" },
    inventory_write_down_gl_account_id: { account_type: "expense", account_category: "inventory_write_down" }
  }.freeze

  FLEXIBLE_GL_FIELDS = %w[
    receiving_clearing_gl_account_id
    freight_in_gl_account_id
    inventory_adjustment_gain_gl_account_id
  ].freeze

  belongs_to :default_tax_class, class_name: "TaxClass"
  belongs_to :inventory_asset_gl_account, class_name: "GlAccount", optional: true
  belongs_to :cost_of_goods_sold_gl_account, class_name: "GlAccount", optional: true
  belongs_to :sales_revenue_gl_account, class_name: "GlAccount", optional: true
  belongs_to :sales_returns_gl_account, class_name: "GlAccount", optional: true
  belongs_to :receiving_clearing_gl_account, class_name: "GlAccount", optional: true
  belongs_to :freight_in_gl_account, class_name: "GlAccount", optional: true
  belongs_to :inventory_shrinkage_gl_account, class_name: "GlAccount", optional: true
  belongs_to :inventory_adjustment_gain_gl_account, class_name: "GlAccount", optional: true
  belongs_to :inventory_adjustment_loss_gl_account, class_name: "GlAccount", optional: true
  belongs_to :inventory_write_down_gl_account, class_name: "GlAccount", optional: true

  before_validation :normalize_department_number

  validates :code, :name, :default_tax_class_id, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :default_target_margin_bps,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10_000 },
            allow_nil: true
  validate :validate_changed_gl_mappings
  validate :validate_changed_tax_class

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:display_order, :department_number, :name) }

  def assignable?
    active?
  end

  def admin_label
    if department_number.present?
      "#{department_number} - #{name}"
    else
      name
    end
  end

  def self.options_for_select(records = admin_ordered)
    Array(records).map { |department| [ department.admin_label, department.id ] }
  end

  def reactivation_blockers
    blockers = []
    if default_tax_class.blank? || !default_tax_class.active?
      blockers << "default tax class must be active"
    end

    GL_MAPPING_EXPECTATIONS.each do |field, expectation|
      account = public_send(field.to_s.delete_suffix("_id"))
      next if account.nil?

      unless account.assignable?
        blockers << "#{field} must be an active posting account"
        next
      end
      if account.account_type != expectation[:account_type] || account.account_category != expectation[:account_category]
        blockers << "#{field} must be #{expectation[:account_type]}/#{expectation[:account_category]}"
      end
    end

    FLEXIBLE_GL_FIELDS.each do |field|
      account = public_send(field.delete_suffix("_id"))
      next if account.nil?

      blockers << "#{field} must be an active posting account" unless account.assignable?
    end

    blockers
  end

  private

  def normalize_department_number
    self.department_number = department_number.to_s.strip.presence
  end

  def validate_changed_tax_class
    return unless default_tax_class_id_changed?
    return if default_tax_class.blank?

    errors.add(:default_tax_class_id, "must be an active tax class") unless default_tax_class.assignable?
  end

  def validate_changed_gl_mappings
    GL_MAPPING_EXPECTATIONS.each do |field, expectation|
      next unless public_send("#{field}_changed?")

      account = public_send(field.to_s.delete_suffix("_id"))
      next if account.nil?

      validate_gl_account_assignment(field, account, expectation)
    end

    FLEXIBLE_GL_FIELDS.each do |field|
      next unless public_send("#{field}_changed?")

      account = public_send(field.delete_suffix("_id"))
      next if account.nil?

      errors.add(field, "must be an active posting account") unless account.assignable?
    end
  end

  def validate_gl_account_assignment(field, account, expectation)
    unless account.assignable?
      errors.add(field, "must be an active posting account")
      return
    end

    if account.account_type != expectation[:account_type] || account.account_category != expectation[:account_category]
      errors.add(field, "must be #{expectation[:account_type]}/#{expectation[:account_category]}")
    end
  end
end
