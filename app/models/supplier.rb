# frozen_string_literal: true

class Supplier < ApplicationRecord
  include HasMachineCode

  has_many :supplier_variant_sources, dependent: :restrict_with_exception
  has_many :orders, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception

  before_validation :normalize_country_code

  validates :code, :name, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :country_code, length: { is: 2 }, allow_nil: true
  validate :cannot_deactivate_with_open_drafts, if: :deactivating?

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:name, :code) }

  def admin_label
    name
  end

  def self.options_for_select(records = active.admin_ordered)
    Array(records).map { |supplier| [ supplier.admin_label, supplier.id ] }
  end

  def reactivation_blockers
    []
  end

  def draft_purchase_order_count
    purchase_orders.where(status: "draft").count
  end

  def unsent_order_count
    orders.joins(purchase_order_line: :purchase_order)
      .where(cancelled_at: nil, purchase_orders: { status: "draft", supplier_id: id })
      .count
  end

  private

  def normalize_country_code
    self.country_code = country_code.to_s.strip.upcase.presence
  end

  def deactivating?
    will_save_change_to_active? && !active
  end

  def cannot_deactivate_with_open_drafts
    draft_pos = draft_purchase_order_count
    unsent = unsent_order_count
    return if draft_pos.zero? && unsent.zero?

    parts = []
    parts << "#{draft_pos} draft purchase #{"order".pluralize(draft_pos)}" if draft_pos.positive?
    parts << "#{unsent} unsent #{"order".pluralize(unsent)}" if unsent.positive?
    errors.add(
      :base,
      "cannot deactivate while #{parts.join(" and ")} still reference this supplier; " \
      "reassign or cancel those drafts first"
    )
  end
end
