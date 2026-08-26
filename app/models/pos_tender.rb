# frozen_string_literal: true

class PosTender < ApplicationRecord
  include UuidV7PrimaryKey

  CATEGORIES = TenderType::CATEGORIES
  DIRECTIONS = %w[payment refund].freeze

  belongs_to :pos_transaction
  belongs_to :configured_tender_type, class_name: "TenderType", foreign_key: :tender_type_id
  belongs_to :post_void_source_tender, class_name: "PosTender", optional: true
  has_one :stored_value_tender_detail, class_name: "PosStoredValueTenderDetail", dependent: :destroy

  validates :configured_tender_type, :tender_number, :tender_type, :tender_name, :behavioral_category,
            :direction, :amount_cents, presence: true
  validates :behavioral_category, inclusion: { in: CATEGORIES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :tender_number, numericality: { only_integer: true, greater_than: 0 }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :cash_presented_matches_applied
  validate :non_cash_omits_presented_and_change

  scope :ordered, -> { order(:tender_number, :id) }
  scope :payments, -> { where(direction: "payment") }
  scope :refunds, -> { where(direction: "refund") }
  scope :cash, -> { where(behavioral_category: "cash") }

  def cash?
    behavioral_category == "cash"
  end

  def stored_value?
    behavioral_category == "stored_value"
  end

  def readonly?
    super || (persisted? && pos_transaction&.commercially_immutable?)
  end

  private

  def cash_presented_matches_applied
    return unless cash?
    return if direction == "refund"

    if amount_presented_cents.nil? || change_cents.nil?
      errors.add(:base, "Cash presented and change are required")
      return
    end
    if amount_presented_cents.negative? || change_cents.negative?
      errors.add(:base, "Cash presented and change must be non-negative")
      return
    end
    return if amount_presented_cents == amount_cents + change_cents

    errors.add(:base, "presented amount must equal applied amount plus change")
  end

  def non_cash_omits_presented_and_change
    return if cash? && direction == "payment"
    return if amount_presented_cents.nil? && change_cents.nil?

    errors.add(:base, "presented and change are only for Cash")
  end
end
