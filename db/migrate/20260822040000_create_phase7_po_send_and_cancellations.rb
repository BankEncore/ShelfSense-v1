# frozen_string_literal: true

class CreatePhase7PoSendAndCancellations < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_order_line_states, id: false do |t|
      t.uuid :purchase_order_line_id, null: false, primary_key: true
      t.integer :confirmed_quantity
      t.integer :backordered_quantity, null: false, default: 0
      t.date :expected_on
      t.string :supplier_reference
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_foreign_key :purchase_order_line_states, :purchase_order_lines,
                    column: :purchase_order_line_id, on_delete: :restrict
    add_check_constraint :purchase_order_line_states,
                         "confirmed_quantity IS NULL OR confirmed_quantity >= 0",
                         name: "purchase_order_line_states_confirmed_quantity_nonnegative"
    add_check_constraint :purchase_order_line_states,
                         "backordered_quantity >= 0",
                         name: "purchase_order_line_states_backordered_quantity_nonnegative"

    create_uuid_table :purchase_order_line_cancellations do |t|
      t.uuid :purchase_order_line_id, null: false
      t.integer :quantity, null: false
      t.string :source, null: false
      t.text :reason, null: false
      t.uuid :recorded_by_id, null: false
      t.timestamptz :occurred_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :purchase_order_line_cancellations, :purchase_order_line_id
    add_index :purchase_order_line_cancellations, :recorded_by_id
    add_foreign_key :purchase_order_line_cancellations, :purchase_order_lines, on_delete: :restrict
    add_foreign_key :purchase_order_line_cancellations, :users, column: :recorded_by_id, on_delete: :restrict
    add_check_constraint :purchase_order_line_cancellations,
                         "quantity > 0",
                         name: "purchase_order_line_cancellations_quantity_positive"
    add_check_constraint :purchase_order_line_cancellations,
                         "source IN ('buyer', 'supplier')",
                         name: "purchase_order_line_cancellations_source_valid"
  end
end
