# frozen_string_literal: true

class GiftCardReplacement < ApplicationRecord
  belongs_to :original_gift_card, class_name: "GiftCard"
  belongs_to :replacement_gift_card, class_name: "GiftCard"
  belongs_to :performed_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :stored_value_operation, optional: true
  belongs_to :reversal_of, class_name: "GiftCardReplacement", optional: true
  has_one :reversed_by, class_name: "GiftCardReplacement", foreign_key: :reversal_of_id, inverse_of: :reversal_of,
          dependent: :restrict_with_exception

  validates :amount_cents, :reason_code, :reason_name_snapshot, :posted_at, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  def readonly?
    super || persisted?
  end
end
