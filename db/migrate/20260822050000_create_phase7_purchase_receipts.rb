# frozen_string_literal: true

class CreatePhase7PurchaseReceipts < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :purchase_receipts do |t|
      t.uuid :store_id, null: false
      t.uuid :supplier_id, null: false
      t.integer :number
      t.string :status, null: false
      t.timestamptz :received_at, null: false
      t.string :supplier_document_number
      t.date :supplier_document_date
      t.integer :freight_cents, null: false, default: 0
      t.integer :handling_cents, null: false, default: 0
      t.integer :supplier_tax_cents, null: false, default: 0
      t.integer :miscellaneous_charges_cents, null: false, default: 0
      t.text :charge_notes
      t.text :notes
      t.timestamptz :posted_at
      t.uuid :posted_by_id
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :purchase_receipts,
              [ :store_id, :number ],
              unique: true,
              where: "number IS NOT NULL",
              name: "index_purchase_receipts_on_store_and_number"
    add_index :purchase_receipts, :supplier_id
    add_index :purchase_receipts, [ :store_id, :status ]
    add_foreign_key :purchase_receipts, :stores, on_delete: :restrict
    add_foreign_key :purchase_receipts, :suppliers, on_delete: :restrict
    add_foreign_key :purchase_receipts, :users, column: :posted_by_id, on_delete: :restrict
    add_check_constraint :purchase_receipts,
                         "status IN ('draft', 'posted', 'reversed')",
                         name: "purchase_receipts_status_valid"
    add_check_constraint :purchase_receipts,
                         "freight_cents >= 0 AND handling_cents >= 0",
                         name: "purchase_receipts_freight_handling_nonnegative"
    add_check_constraint :purchase_receipts,
                         "supplier_tax_cents >= 0 AND miscellaneous_charges_cents >= 0",
                         name: "purchase_receipts_tax_misc_nonnegative"

    create_uuid_table :purchase_receipt_lines do |t|
      t.uuid :purchase_receipt_id, null: false
      t.uuid :purchase_order_line_id, null: false
      t.uuid :product_variant_id, null: false
      t.integer :received_quantity, null: false
      t.integer :matched_quantity, null: false, default: 0
      t.integer :unplanned_quantity, null: false, default: 0
      t.integer :actual_unit_cost_cents, null: false
      t.text :notes
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :purchase_receipt_lines, :purchase_receipt_id
    add_index :purchase_receipt_lines, :purchase_order_line_id
    add_index :purchase_receipt_lines, :product_variant_id
    add_index :purchase_receipt_lines,
              [ :purchase_receipt_id, :purchase_order_line_id ],
              unique: true,
              name: "index_purchase_receipt_lines_on_receipt_and_po_line"
    add_foreign_key :purchase_receipt_lines, :purchase_receipts, on_delete: :restrict
    add_foreign_key :purchase_receipt_lines, :purchase_order_lines, on_delete: :restrict
    add_foreign_key :purchase_receipt_lines, :product_variants, on_delete: :restrict
    add_check_constraint :purchase_receipt_lines,
                         "received_quantity > 0",
                         name: "purchase_receipt_lines_received_quantity_positive"
    add_check_constraint :purchase_receipt_lines,
                         "matched_quantity >= 0 AND unplanned_quantity >= 0",
                         name: "purchase_receipt_lines_matched_unplanned_nonnegative"
    add_check_constraint :purchase_receipt_lines,
                         "actual_unit_cost_cents >= 0",
                         name: "purchase_receipt_lines_actual_cost_nonnegative"
    add_check_constraint :purchase_receipt_lines,
                         "matched_quantity + unplanned_quantity = received_quantity",
                         name: "purchase_receipt_lines_quantities_add_up"

    add_foreign_key :customer_request_allocations, :purchase_receipt_lines,
                    column: :purchase_receipt_line_id, on_delete: :restrict
    add_index :customer_request_allocations, :purchase_receipt_line_id
  end
end
