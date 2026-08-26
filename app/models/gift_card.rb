# frozen_string_literal: true

class GiftCard < ApplicationRecord
  STATUSES = %w[active suspended replaced closed].freeze

  encrypts :number

  belongs_to :gift_card_program
  belongs_to :stored_value_account
  belongs_to :customer, optional: true
  belongs_to :activated_store, class_name: "Store"
  belongs_to :replaced_by, class_name: "GiftCard", optional: true
  has_one :replaced_from, class_name: "GiftCard", foreign_key: :replaced_by_id, inverse_of: :replaced_by,
          dependent: :restrict_with_exception

  validates :number, :number_digest, :number_prefix, :number_last_four, :status, :activated_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :number_digest, uniqueness: true
  validates :number_last_four, length: { is: 4 }
  validate :customer_must_be_canonical_when_present
  validate :number_identity_immutable, on: :update
  before_validation :assign_number_identity, on: :create

  scope :active, -> { where(status: "active") }
  scope :admin_ordered, -> { order(activated_at: :desc) }

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def replaced?
    status == "replaced"
  end

  def closed?
    status == "closed"
  end

  def masked_number
    "#{number_prefix}••••#{number_last_four}"
  end

  def balance_cents
    stored_value_account.balance_cents
  end

  private

  def assign_number_identity
    normalized = GiftCards::Number.normalize(number)
    self.number = normalized
    self.number_digest = GiftCards::Number.digest(normalized)
    self.number_prefix = gift_card_program.prefix
    self.number_last_four = GiftCards::Number.last_four(normalized)
  end

  def customer_must_be_canonical_when_present
    return unless will_save_change_to_customer_id?
    return if customer.blank?
    return if customer.canonical? && customer.active?

    errors.add(:customer_id, "must be an active canonical customer")
  end

  def number_identity_immutable
    %i[number_digest number_prefix number_last_four gift_card_program_id stored_value_account_id].each do |attr|
      errors.add(attr, "cannot change after issue") if will_save_change_to_attribute?(attr)
    end
  end
end
