# frozen_string_literal: true

class PosLineTaxComponent < ApplicationRecord
  belongs_to :pos_transaction_line
  belongs_to :store_tax

  validates :store_tax_code_snapshot, :store_tax_name_snapshot, :rate_percent, :calculation_order, presence: true
  validates :applies, inclusion: { in: [ true, false ] }
  validates :taxable_basis_cents, :tax_cents, numericality: { greater_than_or_equal_to: 0 }
end
