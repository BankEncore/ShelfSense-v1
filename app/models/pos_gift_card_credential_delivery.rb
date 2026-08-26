# frozen_string_literal: true

class PosGiftCardCredentialDelivery < ApplicationRecord
  include UuidV7PrimaryKey

  belongs_to :pos_transaction, optional: true
  belongs_to :gift_card, optional: true

  validates :delivered_at, presence: true
  validate :exactly_one_subject

  private

  def exactly_one_subject
    if pos_transaction_id.present? == gift_card_id.present?
      errors.add(:base, "delivery must key to a POS transaction or a gift card, not both")
    end
  end
end
