# frozen_string_literal: true

class AddInventoryUnitToPosTransactionLines < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_transaction_lines, :inventory_unit_id, :uuid
    add_index :pos_transaction_lines, :inventory_unit_id
    add_foreign_key :pos_transaction_lines, :inventory_units, on_delete: :restrict
    add_check_constraint :pos_transaction_lines,
                         "inventory_unit_id IS NULL OR quantity = 1",
                         name: "pos_transaction_lines_unit_quantity_one"
  end
end
