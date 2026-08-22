# frozen_string_literal: true

class CreatePhase7OrdersAndDraftPos < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :orders do |t|
      t.uuid :store_id, null: false
      t.integer :number, null: false
      t.uuid :product_variant_id, null: false
      t.uuid :supplier_id, null: false
      t.uuid :customer_request_id
      t.integer :requested_quantity, null: false
      t.text :notes
      t.uuid :replaces_order_id
      t.timestamptz :cancelled_at
      t.uuid :cancelled_by_id
      t.text :cancellation_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :orders, [ :store_id, :number ], unique: true
    add_index :orders, :supplier_id
    add_index :orders, :customer_request_id
    add_index :orders, :product_variant_id
    add_index :orders, :replaces_order_id
    add_foreign_key :orders, :stores, on_delete: :restrict
    add_foreign_key :orders, :product_variants, on_delete: :restrict
    add_foreign_key :orders, :suppliers, on_delete: :restrict
    add_foreign_key :orders, :customer_requests, on_delete: :restrict
    add_foreign_key :orders, :orders, column: :replaces_order_id, on_delete: :restrict
    add_foreign_key :orders, :users, column: :cancelled_by_id, on_delete: :restrict
    add_check_constraint :orders,
                         "requested_quantity > 0",
                         name: "orders_requested_quantity_positive"

    create_uuid_table :purchase_orders do |t|
      t.uuid :store_id, null: false
      t.uuid :supplier_id, null: false
      t.integer :number
      t.string :status, null: false
      t.timestamptz :generated_at
      t.uuid :generated_by_id
      t.timestamptz :sent_at
      t.uuid :sent_by_id
      t.string :transmission_method
      t.integer :document_revision, null: false, default: 0
      t.text :notes
      t.timestamptz :closed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :purchase_orders,
              [ :store_id, :number ],
              unique: true,
              where: "number IS NOT NULL",
              name: "index_purchase_orders_on_store_and_number"
    add_index :purchase_orders,
              [ :store_id, :supplier_id ],
              unique: true,
              where: "status = 'draft'",
              name: "index_purchase_orders_one_open_draft_per_store_supplier"
    add_index :purchase_orders, :supplier_id
    add_index :purchase_orders, [ :store_id, :status ]
    add_foreign_key :purchase_orders, :stores, on_delete: :restrict
    add_foreign_key :purchase_orders, :suppliers, on_delete: :restrict
    add_foreign_key :purchase_orders, :users, column: :generated_by_id, on_delete: :restrict
    add_foreign_key :purchase_orders, :users, column: :sent_by_id, on_delete: :restrict
    add_check_constraint :purchase_orders,
                         "status IN ('draft', 'sent', 'closed', 'cancelled')",
                         name: "purchase_orders_status_valid"

    create_uuid_table :purchase_order_lines do |t|
      t.uuid :purchase_order_id, null: false
      t.uuid :order_id, null: false
      t.uuid :product_variant_id, null: false
      t.integer :ordered_quantity, null: false
      t.string :supplier_item_number_snapshot
      t.string :pricing_method_snapshot
      t.integer :supplier_list_price_cents_snapshot
      t.integer :discount_basis_points_snapshot
      t.integer :expected_unit_cost_cents_snapshot, null: false
      t.text :notes_snapshot
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :purchase_order_lines, :order_id, unique: true
    add_index :purchase_order_lines, :purchase_order_id
    add_index :purchase_order_lines, :product_variant_id
    add_foreign_key :purchase_order_lines, :purchase_orders, on_delete: :restrict
    add_foreign_key :purchase_order_lines, :orders, on_delete: :restrict
    add_foreign_key :purchase_order_lines, :product_variants, on_delete: :restrict
    add_check_constraint :purchase_order_lines,
                         "ordered_quantity > 0",
                         name: "purchase_order_lines_ordered_quantity_positive"
    add_check_constraint :purchase_order_lines,
                         "expected_unit_cost_cents_snapshot >= 0",
                         name: "purchase_order_lines_expected_cost_nonnegative"
  end
end
