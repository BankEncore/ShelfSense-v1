# frozen_string_literal: true

class PurchaseOrder < ApplicationRecord
  STATUSES = %w[draft sent closed cancelled].freeze
  TRANSMISSION_METHODS = %w[email fax phone portal other].freeze

  belongs_to :store
  belongs_to :supplier
  belongs_to :generated_by, class_name: "User", optional: true
  belongs_to :sent_by, class_name: "User", optional: true
  has_many :purchase_order_lines, dependent: :restrict_with_exception
  has_many :orders, through: :purchase_order_lines

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :document_revision, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :number, uniqueness: { scope: :store_id }, allow_nil: true
  validates :transmission_method, inclusion: { in: TRANSMISSION_METHODS }, allow_nil: true

  scope :draft, -> { where(status: "draft") }
  scope :sent, -> { where(status: "sent") }
  scope :closed, -> { where(status: "closed") }
  scope :for_store, ->(store) { where(store_id: store.id) }
  scope :with_status, ->(status) { where(status: status) }
  scope :admin_ordered, -> { order(Arel.sql("number DESC NULLS LAST"), :created_at) }

  def draft?
    status == "draft"
  end

  def sent?
    status == "sent"
  end

  def closed?
    status == "closed"
  end

  def generated?
    generated_at.present?
  end

  def unsent?
    sent_at.blank?
  end

  def admin_label
    number.present? ? "PO ##{number}" : "Draft PO"
  end

  def expected_merchandise_total_cents
    purchase_order_lines.sum do |line|
      line.ordered_quantity * line.expected_unit_cost_cents_snapshot
    end
  end

  def all_lines_closed?
    purchase_order_lines.all? { |line| line.open_quantity.zero? }
  end
end

