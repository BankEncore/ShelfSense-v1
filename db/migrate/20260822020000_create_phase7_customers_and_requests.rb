# frozen_string_literal: true

class CreatePhase7CustomersAndRequests < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :store_document_sequences do |t|
      t.uuid :store_id, null: false
      t.string :document_kind, null: false
      t.integer :next_value, null: false, default: 1
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :store_document_sequences,
              [ :store_id, :document_kind ],
              unique: true,
              name: "index_store_document_sequences_on_store_and_kind"
    add_foreign_key :store_document_sequences, :stores, on_delete: :restrict
    add_check_constraint :store_document_sequences,
                         "document_kind IN ('customer_request', 'order', 'purchase_order', 'purchase_receipt')",
                         name: "store_document_sequences_kind_valid"
    add_check_constraint :store_document_sequences,
                         "next_value > 0",
                         name: "store_document_sequences_next_value_positive"

    create_uuid_table :customers do |t|
      t.string :display_name, null: false
      t.string :email
      t.string :phone
      t.text :notes
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :customers, :display_name
    add_index :customers, :email
    add_index :customers, :phone

    create_uuid_table :customer_requests do |t|
      t.uuid :store_id, null: false
      t.integer :number, null: false
      t.uuid :customer_id, null: false
      t.uuid :product_variant_id, null: false
      t.integer :requested_quantity, null: false, default: 1
      t.integer :estimated_price_cents
      t.text :notes
      t.string :status, null: false
      t.timestamptz :location_failed_at
      t.uuid :location_failed_by_id
      t.text :location_failure_notes
      t.timestamptz :cancelled_at
      t.uuid :cancelled_by_id
      t.text :cancellation_reason
      t.timestamptz :completed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :customer_requests, [ :store_id, :number ], unique: true
    add_index :customer_requests, [ :store_id, :status ]
    add_index :customer_requests, :customer_id
    add_index :customer_requests, :product_variant_id
    add_foreign_key :customer_requests, :stores, on_delete: :restrict
    add_foreign_key :customer_requests, :customers, on_delete: :restrict
    add_foreign_key :customer_requests, :product_variants, on_delete: :restrict
    add_foreign_key :customer_requests, :users, column: :location_failed_by_id, on_delete: :restrict
    add_foreign_key :customer_requests, :users, column: :cancelled_by_id, on_delete: :restrict
    add_check_constraint :customer_requests,
                         "requested_quantity = 1",
                         name: "customer_requests_quantity_one"
    add_check_constraint :customer_requests,
                         "status IN ('pending_location', 'special_order_pending', 'ordered', 'available', 'completed', 'cancelled')",
                         name: "customer_requests_status_valid"

    create_uuid_table :customer_request_allocations do |t|
      t.uuid :customer_request_id, null: false
      t.string :allocation_type, null: false
      t.uuid :purchase_receipt_line_id
      t.uuid :inventory_unit_id
      t.integer :quantity, null: false, default: 1
      t.string :status, null: false
      t.uuid :fulfilled_pos_transaction_line_id
      t.timestamptz :released_at
      t.uuid :released_by_id
      t.text :release_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :customer_request_allocations, :customer_request_id
    add_index :customer_request_allocations,
              :customer_request_id,
              unique: true,
              where: "status = 'reserved'",
              name: "index_customer_request_allocations_one_reserved_per_request"
    add_index :customer_request_allocations,
              :inventory_unit_id,
              unique: true,
              where: "allocation_type = 'used_unit' AND status = 'reserved'",
              name: "index_customer_request_allocations_one_reserved_per_unit"
    add_index :customer_request_allocations, :inventory_unit_id
    add_foreign_key :customer_request_allocations, :customer_requests, on_delete: :restrict
    add_foreign_key :customer_request_allocations, :inventory_units, on_delete: :restrict
    add_foreign_key :customer_request_allocations, :pos_transaction_lines,
                    column: :fulfilled_pos_transaction_line_id, on_delete: :restrict
    add_foreign_key :customer_request_allocations, :users, column: :released_by_id, on_delete: :restrict
    add_check_constraint :customer_request_allocations,
                         "quantity = 1",
                         name: "customer_request_allocations_quantity_one"
    add_check_constraint :customer_request_allocations,
                         "allocation_type IN ('standard_quantity', 'used_unit')",
                         name: "customer_request_allocations_type_valid"
    add_check_constraint :customer_request_allocations,
                         "status IN ('reserved', 'fulfilled', 'released')",
                         name: "customer_request_allocations_status_valid"
    add_check_constraint :customer_request_allocations,
                         "(allocation_type = 'used_unit' AND inventory_unit_id IS NOT NULL) OR (allocation_type = 'standard_quantity' AND inventory_unit_id IS NULL)",
                         name: "customer_request_allocations_unit_matches_type"
  end
end
