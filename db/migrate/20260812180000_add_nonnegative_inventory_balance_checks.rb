# frozen_string_literal: true

class AddNonnegativeInventoryBalanceChecks < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :inventory_balances,
                         "on_hand_quantity >= 0",
                         name: "inventory_balances_on_hand_nonnegative"
    add_check_constraint :inventory_balances,
                         "inventory_value_cents >= 0",
                         name: "inventory_balances_value_nonnegative"
  end
end
