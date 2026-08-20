# frozen_string_literal: true

class AddPosTransactionLinePricingMethodSnapshot < ActiveRecord::Migration[8.1]
  def up
    add_column :pos_transaction_lines, :pricing_method_snapshot, :string, null: false, default: "configured"
    add_check_constraint :pos_transaction_lines,
                         "pricing_method_snapshot IN ('open_price', 'configured')",
                         name: "pos_transaction_lines_pricing_method_snapshot_valid"
  end

  def down
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_pricing_method_snapshot_valid"
    remove_column :pos_transaction_lines, :pricing_method_snapshot
  end
end
