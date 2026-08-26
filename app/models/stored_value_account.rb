# frozen_string_literal: true

class StoredValueAccount < ApplicationRecord
  ACCOUNT_TYPES = %w[store_credit trade_credit gift_card].freeze
  STATUSES = %w[active suspended closed].freeze
  CUSTOMER_OWNED_TYPES = %w[store_credit trade_credit].freeze

  belongs_to :customer, optional: true
  has_many :stored_value_entries, dependent: :restrict_with_exception

  validates :account_type, :currency_code, :status, :opened_at, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :currency_code, length: { is: 3 }
  validates :balance_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :customer_matches_account_type
  validate :closed_consistency
  validate :type_and_currency_immutable, on: :update

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def closed?
    status == "closed"
  end

  def customer_owned?
    CUSTOMER_OWNED_TYPES.include?(account_type)
  end

  def close_zero!(at: Time.current)
    raise StoredValue::Error, "cannot close an account with a nonzero balance" unless balance_cents.to_i.zero?

    update!(status: "closed", closed_at: at)
  end

  def apply_posted_balance!(cents)
    @allow_balance_write = true
    update!(balance_cents: cents)
  ensure
    @allow_balance_write = false
  end

  def balance_cents=(value)
    if persisted? && !@allow_balance_write
      raise StoredValue::Error, "balance_cents cannot be assigned via generic update"
    end

    super
  end

  private

  def customer_matches_account_type
    if customer_owned?
      errors.add(:customer_id, "is required") if customer_id.blank?
    elsif account_type == "gift_card" && customer_id.present?
      errors.add(:customer_id, "must be blank for gift-card accounts")
    end
  end

  def closed_consistency
    if status == "closed"
      errors.add(:closed_at, "is required") if closed_at.blank?
      errors.add(:balance_cents, "must be zero when closed") unless balance_cents.to_i.zero?
    elsif closed_at.present?
      errors.add(:closed_at, "must be blank unless closed")
    end
  end

  def type_and_currency_immutable
    errors.add(:account_type, "cannot change after open") if will_save_change_to_account_type?
    errors.add(:currency_code, "cannot change after open") if will_save_change_to_currency_code?
  end
end
