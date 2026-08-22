# frozen_string_literal: true

class CustomerRequest < ApplicationRecord
  STATUSES = %w[
    pending_location
    special_order_pending
    ordered
    available
    completed
    cancelled
  ].freeze

  LOCATEABLE_STATUSES = %w[pending_location].freeze
  ACTIVE_STATUSES = %w[pending_location special_order_pending ordered available].freeze

  belongs_to :store
  belongs_to :customer
  belongs_to :product_variant
  belongs_to :location_failed_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_many :customer_request_allocations, dependent: :restrict_with_exception
  has_many :orders, dependent: :restrict_with_exception

  validates :number, :status, :requested_quantity, presence: true
  validates :number, uniqueness: { scope: :store_id }
  validates :requested_quantity, numericality: { equal_to: 1 }
  validates :status, inclusion: { in: STATUSES }
  validates :estimated_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            allow_nil: true
  validates :cancellation_reason, :cancelled_at, :cancelled_by_id, presence: true, if: :cancelled?
  validates :cancelled_at, :cancelled_by_id, :cancellation_reason, absence: true, unless: :cancelled?

  scope :pending_location, -> { where(status: "pending_location") }
  scope :available, -> { where(status: "available") }
  scope :for_store, ->(store) { where(store_id: store.id) }
  scope :admin_ordered, -> { order(number: :desc) }

  def pending_location?
    status == "pending_location"
  end

  def special_order_pending?
    status == "special_order_pending"
  end

  def available?
    status == "available"
  end

  def cancelled?
    status == "cancelled"
  end

  def completed?
    status == "completed"
  end

  def unsent_special_orders
    orders.active.select(&:unsent?)
  end

  def active_allocation
    customer_request_allocations.find_by(status: "reserved")
  end

  def admin_label
    "Request ##{number}"
  end
end
