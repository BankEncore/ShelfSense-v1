# frozen_string_literal: true

class TaxClass < ApplicationRecord
  include HasMachineCode

  validates :code, :name, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }

  scope :active, -> { where(active: true) }
  scope :assignable, -> { active }
  scope :admin_ordered, -> { order(:display_order, :name) }

  def assignable?
    active?
  end

  def admin_label
    name
  end

  def self.options_for_select(records = admin_ordered)
    Array(records).map { |tax_class| [ tax_class.admin_label, tax_class.id ] }
  end

  def reactivation_blockers
    []
  end
end
