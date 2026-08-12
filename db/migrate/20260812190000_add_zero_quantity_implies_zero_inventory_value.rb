# frozen_string_literal: true

class AddZeroQuantityImpliesZeroInventoryValue < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :inventory_balances,
                         "on_hand_quantity <> 0 OR inventory_value_cents = 0",
                         name: "inventory_balances_zero_qty_zero_value"
  end
end
