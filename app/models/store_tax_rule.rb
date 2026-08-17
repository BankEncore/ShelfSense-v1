# frozen_string_literal: true

class StoreTaxRule < ApplicationRecord
  belongs_to :store_tax
  belongs_to :tax_class

  validates :store_tax_id, uniqueness: { scope: :tax_class_id }
end
