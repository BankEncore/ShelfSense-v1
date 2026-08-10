# frozen_string_literal: true

class Store < ApplicationRecord
  belongs_to :deactivated_by, class_name: "User", optional: true
  has_many :workstations, dependent: :restrict_with_exception
  has_many :role_assignments, dependent: :restrict_with_exception

  before_validation :normalize_codes

  validates :store_number, :code, :name, :country_code, :timezone, presence: true
  validates :country_code, length: { is: 2 }
  validates :store_number, uniqueness: { case_sensitive: false }
  validates :code, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }

  private

  def normalize_codes
    self.store_number = store_number.to_s.strip
    self.code = code.to_s.strip.downcase
    self.country_code = country_code.to_s.strip.upcase
  end
end
