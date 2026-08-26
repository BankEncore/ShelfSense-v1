# frozen_string_literal: true

class PosStoredValueIssuance < ApplicationRecord
  ISSUANCE_TYPES = %w[activation reload].freeze
  AUTHORITIES = %w[system_generated manual_external].freeze

  encrypts :pending_card_number

  belongs_to :pos_transaction
  belongs_to :gift_card_program, optional: true
  belongs_to :gift_card, optional: true
  belongs_to :stored_value_operation, optional: true
  belongs_to :post_void_source_issuance, class_name: "PosStoredValueIssuance", optional: true

  validates :issuance_number, :issuance_type, :amount_cents, :number_authority, presence: true
  validates :issuance_type, inclusion: { in: ISSUANCE_TYPES }
  validates :number_authority, inclusion: { in: AUTHORITIES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :issuance_number, numericality: { only_integer: true, greater_than: 0 }
  validate :reload_requires_card
  validate :activation_requires_program
  before_validation :assign_pending_identity, if: -> { pending_card_number.present? && will_save_change_to_pending_card_number? }

  scope :ordered, -> { order(:issuance_number, :id) }

  def activation?
    issuance_type == "activation"
  end

  def reload_issuance?
    issuance_type == "reload"
  end

  def post_void_generated?
    post_void_source_issuance_id.present?
  end

  def system_generated?
    number_authority == "system_generated"
  end

  def readonly?
    super || (persisted? && pos_transaction&.commercially_immutable?)
  end

  private

  def assign_pending_identity
    normalized = GiftCards::Number.normalize(pending_card_number)
    self.pending_card_number = normalized
    self.pending_card_number_digest = GiftCards::Number.digest(normalized)
    self.pending_card_number_last_four = GiftCards::Number.last_four(normalized)
    self.pending_card_number_prefix = gift_card_program&.prefix
  end

  def reload_requires_card
    return unless reload_issuance?

    errors.add(:gift_card_id, "is required for reload") if gift_card_id.blank?
  end

  def activation_requires_program
    return unless activation?

    errors.add(:gift_card_program_id, "is required for activation") if gift_card_program_id.blank?
  end
end
