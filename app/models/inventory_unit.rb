# frozen_string_literal: true

class InventoryUnit < ApplicationRecord
  include UuidV7PrimaryKey

  LIFECYCLE_STATES = %w[on_hand removed].freeze

  belongs_to :product_variant
  belongs_to :store
  has_many :inventory_adjustments, dependent: :restrict_with_exception
  has_many :pos_transaction_lines, dependent: :restrict_with_exception

  validates :unit_identifier, :lifecycle_state, :acquisition_cost_cents, :carrying_value_cents, presence: true
  validates :unit_identifier, uniqueness: true, format: { with: /\A\d{13}\z/ }
  validates :lifecycle_state, inclusion: { in: LIFECYCLE_STATES }
  validates :acquisition_cost_cents, :carrying_value_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :regular_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :on_hand, -> { where(lifecycle_state: "on_hand") }

  def on_hand?
    lifecycle_state == "on_hand"
  end

  def removed?
    lifecycle_state == "removed"
  end

  def effective_regular_price_cents
    regular_price_cents.presence || product_variant.regular_price_cents
  end
end
