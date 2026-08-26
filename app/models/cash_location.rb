# frozen_string_literal: true

class CashLocation < ApplicationRecord
  LOCATION_TYPES = %w[safe deposit_in_transit].freeze

  belongs_to :store
  has_many :cash_entries, dependent: :restrict_with_exception
  has_many :cash_counts, dependent: :restrict_with_exception
  has_one :cash_safe_initialization, dependent: :restrict_with_exception

  validates :location_type, presence: true, inclusion: { in: LOCATION_TYPES }
  validates :expected_balance_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :location_type_immutable, on: :update

  scope :safes, -> { where(location_type: "safe") }
  scope :deposit_in_transit, -> { where(location_type: "deposit_in_transit") }

  def safe?
    location_type == "safe"
  end

  def deposit_in_transit?
    location_type == "deposit_in_transit"
  end

  def initialized?
    initialized_at.present?
  end

  def apply_posted_balance!(cents)
    @allow_balance_write = true
    update!(expected_balance_cents: cents)
  ensure
    @allow_balance_write = false
  end

  def expected_balance_cents=(value)
    if persisted? && !@allow_balance_write
      raise Cash::Error, "expected_balance_cents cannot be assigned via generic update"
    end

    super
  end

  private

  def location_type_immutable
    errors.add(:location_type, "cannot change after create") if will_save_change_to_location_type?
  end
end
