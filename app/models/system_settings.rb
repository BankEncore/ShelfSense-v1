# frozen_string_literal: true

class SystemSettings < ApplicationRecord
  self.table_name = "system_settings"

  validates :organization_name, :base_currency_code, :default_timezone, :default_country_code, presence: true
  validates :base_currency_code, length: { is: 3 }
  validates :default_country_code, length: { is: 2 }
  validates :fiscal_year_start_month, inclusion: { in: 1..12 }
  validates :default_supplier_cancellation_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :default_customer_reservation_expiration_days,
            numericality: { only_integer: true, greater_than: 0 }
  validate :singleton_row

  def self.current
    record = order(:created_at).first
    raise "System settings are not configured" if record.nil?
    raise "Multiple system settings rows exist" if count > 1

    record
  end

  def self.initialized?
    exists?(singleton_key: true) && where.not(initialized_at: nil).exists?
  end

  def initialized?
    initialized_at.present?
  end

  private

  def singleton_row
    errors.add(:singleton_key, "must be true") unless singleton_key == true
  end
end
