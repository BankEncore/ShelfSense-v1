# frozen_string_literal: true

class AddPosForeignKeyIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :pos_reporting_periods, :store_id
    add_index :pos_reporting_periods, :register_id, name: "index_pos_reporting_periods_on_register_id"

    add_index :pos_sessions, :store_id
    add_index :pos_sessions, :register_id, name: "index_pos_sessions_on_register_id"
    add_index :pos_sessions, :reporting_period_id
    add_index :pos_sessions, :cashier_user_id

    add_index :pos_transactions, :store_id
    add_index :pos_transactions, :register_id
    add_index :pos_transactions, :pos_session_id
    add_index :pos_transactions, :reporting_period_id
    add_index :pos_transactions, :cashier_user_id

    add_index :pos_transaction_lines, :product_variant_id
    add_index :pos_transaction_lines, :tax_class_id

    add_index :pos_line_tax_components, :store_tax_id

    add_index :pos_tenders, :pos_transaction_id

    add_index :pos_operations, :pos_transaction_id
    add_index :pos_operations, :store_id
    add_index :pos_operations, :register_id
  end
end
