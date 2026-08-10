# frozen_string_literal: true

class GlAccount < ApplicationRecord
  ACCOUNT_TYPES = %w[asset liability equity revenue expense].freeze
  ACCOUNT_CATEGORIES = %w[
    cash accounts_receivable inventory other_current_asset fixed_asset
    accounts_payable other_current_liability long_term_liability equity
    sales sales_returns cost_of_goods_sold freight_in inventory_shrinkage
    inventory_adjustment inventory_write_down other_revenue other_expense
  ].freeze

  belongs_to :parent, class_name: "GlAccount", optional: true
  has_many :children, class_name: "GlAccount", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_exception

  before_validation :normalize_account_number

  validates :account_number, :name, :account_type, :account_category, presence: true
  validates :account_number, uniqueness: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :account_category, inclusion: { in: ACCOUNT_CATEGORIES }
  validate :parent_not_self
  validate :parent_same_account_type
  validate :no_parent_cycle

  scope :active, -> { where(active: true) }
  scope :posting, -> { where(posting_allowed: true) }
  scope :assignable, -> { active.posting }

  def assignable?
    active? && posting_allowed?
  end

  private

  def normalize_account_number
    self.account_number = account_number.to_s.strip
  end

  def parent_not_self
    return if parent_id.blank? || id.blank?
    errors.add(:parent_id, "cannot reference itself") if parent_id == id
  end

  def parent_same_account_type
    return if parent.blank?
    errors.add(:parent_id, "must have the same account type") if parent.account_type != account_type
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
end
