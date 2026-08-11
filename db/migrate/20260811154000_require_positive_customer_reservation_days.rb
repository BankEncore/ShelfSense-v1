# frozen_string_literal: true

class RequirePositiveCustomerReservationDays < ActiveRecord::Migration[8.1]
  def up
    bad = connection.select_value(<<~SQL.squish)
      SELECT COUNT(*) FROM system_settings
      WHERE default_customer_reservation_expiration_days IS NULL
         OR default_customer_reservation_expiration_days < 1
    SQL
    if bad.to_i.positive?
      raise ActiveRecord::IrreversibleMigration,
            "default_customer_reservation_expiration_days must be >= 1 before tightening the constraint"
    end

    remove_check_constraint :system_settings, name: "system_settings_reservation_days_nonnegative"
    add_check_constraint :system_settings,
                         "default_customer_reservation_expiration_days > 0",
                         name: "system_settings_reservation_days_positive"
  end

  def down
    remove_check_constraint :system_settings, name: "system_settings_reservation_days_positive"
    add_check_constraint :system_settings,
                         "default_customer_reservation_expiration_days >= 0",
                         name: "system_settings_reservation_days_nonnegative"
  end
end
