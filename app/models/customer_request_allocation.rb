# frozen_string_literal: true

class CustomerRequestAllocation < ApplicationRecord
  ALLOCATION_TYPES = %w[standard_quantity used_unit].freeze
  STATUSES = %w[reserved fulfilled released].freeze

  belongs_to :customer_request
  belongs_to :purchase_receipt_line, optional: true
  belongs_to :inventory_unit, optional: true
  belongs_to :fulfilled_pos_transaction_line, class_name: "PosTransactionLine", optional: true
  belongs_to :released_by, class_name: "User", optional: true

  validates :allocation_type, :status, :quantity, presence: true
  validates :allocation_type, inclusion: { in: ALLOCATION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { equal_to: 1 }
  validates :inventory_unit_id, presence: true, if: :used_unit?
  validates :inventory_unit_id, absence: true, if: :standard_quantity?
  validates :released_at, :released_by_id, :release_reason, presence: true, if: :released?
  validates :fulfilled_pos_transaction_line_id, presence: true, if: :fulfilled?

  scope :reserved, -> { where(status: "reserved") }
  scope :standard_quantity, -> { where(allocation_type: "standard_quantity") }
  scope :used_unit, -> { where(allocation_type: "used_unit") }

  def standard_quantity?
    allocation_type == "standard_quantity"
  end

  def used_unit?
    allocation_type == "used_unit"
  end

  def reserved?
    status == "reserved"
  end

  def released?
    status == "released"
  end

  def fulfilled?
    status == "fulfilled"
  end
end
