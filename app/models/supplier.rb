# frozen_string_literal: true

class Supplier < ApplicationRecord
  include HasMachineCode

  has_many :supplier_variant_sources, dependent: :restrict_with_exception
  has_many :orders, dependent: :restrict_with_exception
  has_many :purchase_orders, dependent: :restrict_with_exception

  before_validation :normalize_country_code

  validates :code, :name, presence: true
  validates :code, uniqueness: true, format: { with: Codes::Normalizer::FORMAT }
  validates :country_code, length: { is: 2 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :admin_ordered, -> { order(:name, :code) }

  def admin_label
    name
  end

  def self.options_for_select(records = active.admin_ordered)
    Array(records).map { |supplier| [ supplier.admin_label, supplier.id ] }
  end

  def reactivation_blockers
    []
  end

  private

  def normalize_country_code
    self.country_code = country_code.to_s.strip.upcase.presence
  end
end
