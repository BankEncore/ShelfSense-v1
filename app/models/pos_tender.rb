# frozen_string_literal: true

class PosTender < ApplicationRecord
  TENDER_TYPES = %w[cash].freeze
  DIRECTIONS = %w[payment].freeze

  belongs_to :pos_transaction

  validates :tender_type, :direction, :amount_cents, :amount_presented_cents, :change_cents, presence: true
  validates :tender_type, inclusion: { in: TENDER_TYPES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :amount_cents, :amount_presented_cents, :change_cents, numericality: { greater_than_or_equal_to: 0 }
end
