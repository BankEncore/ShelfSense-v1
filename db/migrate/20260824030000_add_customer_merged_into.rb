# frozen_string_literal: true

class AddCustomerMergedInto < ActiveRecord::Migration[8.1]
  def change
    add_reference :customers,
                  :merged_into_customer,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :customers, on_delete: :restrict },
                  index: true

    add_check_constraint :customers,
                         "merged_into_customer_id IS NULL OR active = false",
                         name: "customers_merged_implies_inactive_check"

    add_check_constraint :customers,
                         "merged_into_customer_id IS NULL OR merged_into_customer_id <> id",
                         name: "customers_merged_into_not_self_check"
  end
end
