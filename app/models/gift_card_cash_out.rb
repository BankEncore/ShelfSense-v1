# frozen_string_literal: true

class GiftCardCashOut < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :gift_card
  belongs_to :stored_value_account
  belongs_to :register
  belongs_to :pos_session
  belongs_to :store
  belongs_to :performed_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :physical_cash_confirmed_by, class_name: "User", optional: true
  belongs_to :stored_value_operation, optional: true
  belongs_to :reversal_of, class_name: "GiftCardCashOut", optional: true
  has_one :reversed_by, class_name: "GiftCardCashOut", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception
  has_one :pos_controlled_action, dependent: :restrict_with_exception

  validates :amount_cents, :business_date, :posted_at, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :originals, -> { where(reversal_of_id: nil) }
  scope :reversals, -> { where.not(reversal_of_id: nil) }

  def reversal?
    reversal_of_id.present?
  end

  def reversed?
    reversed_by.present?
  end

  def readonly?
    super || persisted?
  end
end
