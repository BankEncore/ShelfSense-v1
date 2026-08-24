# frozen_string_literal: true

class AddCustomerContactNormalization < ActiveRecord::Migration[8.1]
  def up
    change_table :customers, bulk: true do |t|
      t.string :email_normalized
      t.string :phone_normalized
      t.string :preferred_contact_method, null: false, default: "none"
    end

    add_index :customers, :email_normalized
    add_index :customers, :phone_normalized

    add_check_constraint :customers,
                         "preferred_contact_method IN ('phone', 'email', 'none')",
                         name: "customers_preferred_contact_method_check"

    say_with_time "backfill customer contact normalization" do
      Customer.reset_column_information
      Customer.find_each do |customer|
        Customers::NormalizeContact.apply!(customer)
        customer.update_columns(
          email_normalized: customer.email_normalized,
          phone_normalized: customer.phone_normalized
        )
      end
    end
  end

  def down
    remove_check_constraint :customers, name: "customers_preferred_contact_method_check"
    remove_index :customers, :email_normalized
    remove_index :customers, :phone_normalized
    change_table :customers, bulk: true do |t|
      t.remove :email_normalized, :phone_normalized, :preferred_contact_method
    end
  end
end
