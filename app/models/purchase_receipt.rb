# frozen_string_literal: true

class PurchaseReceipt < ApplicationRecord
  STATUSES = %w[draft posted reversed].freeze

  belongs_to :store
  belongs_to :supplier
  belongs_to :posted_by, class_name: "User", optional: true
  has_many :purchase_receipt_lines, dependent: :restrict_with_exception
  has_many :corrections, through: :purchase_receipt_lines

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :received_at, presence: true
  validates :freight_cents, :handling_cents, :supplier_tax_cents, :miscellaneous_charges_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :number, uniqueness: { scope: :store_id }, allow_nil: true
  validates :posted_at, :posted_by_id, presence: true, if: :posted?
  validates :charge_notes, presence: true, if: -> { miscellaneous_charges_cents.to_i != 0 }
  validate :received_at_not_future

  scope :draft, -> { where(status: "draft") }
  scope :posted, -> { where(status: "posted") }
  scope :for_store, ->(store) { where(store_id: store.id) }
  scope :admin_ordered, -> { order(Arel.sql("number DESC NULLS LAST"), :created_at) }

  def draft?
    status == "draft"
  end

  def posted?
    status == "posted"
  end

  def reversed?
    status == "reversed"
  end

  def admin_label
    number.present? ? "Receipt ##{number}" : "Draft receipt"
  end

  def merchandise_total_cents
    purchase_receipt_lines.sum { |line| line.received_quantity * line.actual_unit_cost_cents }
  end

  def ancillary_total_cents
    freight_cents + handling_cents + supplier_tax_cents + miscellaneous_charges_cents
  end

  def operational_acquisition_total_cents
    merchandise_total_cents + ancillary_total_cents
  end

  private

  def received_at_not_future
    return if received_at.blank?
    return if received_at <= Time.current + 1.second

    errors.add(:received_at, "cannot be in the future")
  end
end
