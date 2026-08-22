# frozen_string_literal: true

class CreatePhase7ReceiptCorrections < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :purchase_receipt_line_corrections do |t|
      t.uuid :purchase_receipt_line_id, null: false
      t.string :correction_type, null: false
      t.integer :quantity
      t.bigint :value_delta_cents
      t.text :reason, null: false
      t.uuid :recorded_by_id, null: false
      t.timestamptz :recorded_at, null: false
      t.string :inventory_source_type
      t.uuid :inventory_source_id
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :purchase_receipt_line_corrections, :purchase_receipt_line_id
    add_index :purchase_receipt_line_corrections, :recorded_by_id
    add_index :purchase_receipt_line_corrections,
              [ :inventory_source_type, :inventory_source_id ],
              name: "index_prl_corrections_on_inventory_source"
    add_foreign_key :purchase_receipt_line_corrections, :purchase_receipt_lines, on_delete: :restrict
    add_foreign_key :purchase_receipt_line_corrections, :users, column: :recorded_by_id, on_delete: :restrict
    add_check_constraint :purchase_receipt_line_corrections,
                         "correction_type IN ('quantity_reversal', 'cost_correction', 'compensating_adjustment_reference')",
                         name: "prl_corrections_type_valid"
    add_check_constraint :purchase_receipt_line_corrections,
                         "(correction_type = 'quantity_reversal' AND quantity > 0) OR (correction_type <> 'quantity_reversal' AND quantity IS NULL)",
                         name: "prl_corrections_quantity_matches_type"
    add_check_constraint :purchase_receipt_line_corrections,
                         "(correction_type = 'cost_correction' AND value_delta_cents IS NOT NULL AND value_delta_cents <> 0) OR (correction_type <> 'cost_correction')",
                         name: "prl_corrections_cost_value_present"

    # Cost-only receipt corrections post paired ledger/valuation rows with quantity_delta = 0.
    remove_check_constraint :inventory_ledger_entries, name: "inventory_ledger_entries_quantity_nonzero"
    add_check_constraint :inventory_ledger_entries,
                         "quantity_delta <> 0 OR entry_type = 'cost_correction'",
                         name: "inventory_ledger_entries_quantity_nonzero_or_cost_correction"
  end
end
