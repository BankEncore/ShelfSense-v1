# frozen_string_literal: true

class PosStoredValueTenderDetail < ApplicationRecord
  DESTINATION_MODES = %w[existing_account customer_store_credit new_gift_card].freeze

  encrypts :pending_card_number

  belongs_to :pos_tender
  belongs_to :stored_value_operation, optional: true
  belongs_to :stored_value_account, optional: true
  belongs_to :gift_card, optional: true
  belongs_to :gift_card_program, optional: true

  validates :destination_mode, presence: true, inclusion: { in: DESTINATION_MODES }
  validate :existing_account_has_target
  before_validation :assign_pending_identity, if: -> { pending_card_number.present? && will_save_change_to_pending_card_number? }

  def existing_account?
    destination_mode == "existing_account"
  end

  def customer_store_credit?
    destination_mode == "customer_store_credit"
  end

  def new_gift_card?
    destination_mode == "new_gift_card"
  end

  def readonly?
    super || (persisted? && pos_tender&.pos_transaction&.commercially_immutable?)
  end

  private

  def assign_pending_identity
    normalized = GiftCards::Number.normalize(pending_card_number)
    self.pending_card_number = normalized
    self.pending_card_number_digest = GiftCards::Number.digest(normalized)
    self.pending_card_number_last_four = GiftCards::Number.last_four(normalized)
    self.pending_card_number_prefix = gift_card_program&.prefix
  end

  def existing_account_has_target
    return unless existing_account?
    return if stored_value_account_id.present?

    errors.add(:stored_value_account_id, "is required for an existing account")
  end
end
