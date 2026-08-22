# frozen_string_literal: true

class AddAllocationToPosTransactionLines < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_transaction_lines, :customer_request_allocation_id, :uuid
    add_index :pos_transaction_lines, :customer_request_allocation_id
    add_foreign_key :pos_transaction_lines, :customer_request_allocations, on_delete: :restrict
  end
end
