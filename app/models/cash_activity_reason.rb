# frozen_string_literal: true

class CashActivityReason < ApplicationRecord
  OPERATION_KINDS = %w[paid_in paid_out over short reverse].freeze

  validates :code, :name, :operation_kind, presence: true
  validates :operation_kind, inclusion: { in: OPERATION_KINDS }
  validates :code, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
end
