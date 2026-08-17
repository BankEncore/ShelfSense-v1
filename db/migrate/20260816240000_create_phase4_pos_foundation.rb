# frozen_string_literal: true

class CreatePhase4PosFoundation < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :pos_reporting_periods do |t|
      t.uuid :store_id, null: false
      t.uuid :register_id, null: false
      t.string :status, null: false
      t.timestamptz :opened_at, null: false
      t.timestamptz :closed_at
      t.date :business_date, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_reporting_periods, :register_id, unique: true, where: "status = 'open'", name: "index_pos_reporting_periods_one_open_per_register"
    add_check_constraint :pos_reporting_periods, "status IN ('open', 'finalized')", name: "pos_reporting_periods_status_valid"
    add_check_constraint :pos_reporting_periods,
                         "(status = 'open' AND closed_at IS NULL) OR (status = 'finalized' AND closed_at IS NOT NULL)",
                         name: "pos_reporting_periods_closed_at_matches_status"
    add_foreign_key :pos_reporting_periods, :stores
    add_foreign_key :pos_reporting_periods, :registers

    create_uuid_table :pos_sessions do |t|
      t.uuid :store_id, null: false
      t.uuid :register_id, null: false
      t.uuid :reporting_period_id, null: false
      t.uuid :cashier_user_id, null: false
      t.string :status, null: false
      t.timestamptz :opened_at, null: false
      t.timestamptz :closed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_sessions, :register_id, unique: true, where: "status = 'open'", name: "index_pos_sessions_one_open_per_register"
    add_check_constraint :pos_sessions, "status IN ('open', 'closed')", name: "pos_sessions_status_valid"
    add_check_constraint :pos_sessions,
                         "(status = 'open' AND closed_at IS NULL) OR (status = 'closed' AND closed_at IS NOT NULL)",
                         name: "pos_sessions_closed_at_matches_status"
    add_foreign_key :pos_sessions, :stores
    add_foreign_key :pos_sessions, :registers
    add_foreign_key :pos_sessions, :pos_reporting_periods, column: :reporting_period_id
    add_foreign_key :pos_sessions, :users, column: :cashier_user_id

    create_uuid_table :pos_transactions do |t|
      t.uuid :store_id, null: false
      t.uuid :register_id, null: false
      t.uuid :pos_session_id, null: false
      t.uuid :reporting_period_id, null: false
      t.uuid :cashier_user_id, null: false
      t.string :status, null: false
      t.string :currency_code, limit: 3, null: false
      t.timestamptz :occurred_at
      t.date :business_date
      t.timestamptz :completed_at
      t.timestamptz :cancelled_at
      t.bigint :receipt_sequence
      t.string :store_number_snapshot
      t.string :register_number_snapshot
      t.string :transaction_reference
      t.bigint :subtotal_cents, null: false, default: 0
      t.bigint :tax_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_transactions, %i[store_id register_id receipt_sequence], unique: true, where: "receipt_sequence IS NOT NULL", name: "index_pos_transactions_receipt_identity"
    add_index :pos_transactions, :transaction_reference, unique: true, where: "transaction_reference IS NOT NULL"
    add_check_constraint :pos_transactions, "status IN ('working', 'completed', 'cancelled')", name: "pos_transactions_status_valid"
    add_check_constraint :pos_transactions, <<~SQL.squish, name: "pos_transactions_status_null_rules"
      (status = 'working' AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL AND completed_at IS NULL AND cancelled_at IS NULL)
      OR (status = 'completed' AND receipt_sequence IS NOT NULL AND store_number_snapshot IS NOT NULL AND register_number_snapshot IS NOT NULL AND completed_at IS NOT NULL AND cancelled_at IS NULL)
      OR (status = 'cancelled' AND receipt_sequence IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL)
    SQL
    add_foreign_key :pos_transactions, :stores
    add_foreign_key :pos_transactions, :registers
    add_foreign_key :pos_transactions, :pos_sessions
    add_foreign_key :pos_transactions, :pos_reporting_periods, column: :reporting_period_id
    add_foreign_key :pos_transactions, :users, column: :cashier_user_id

    create_uuid_table :pos_transaction_lines do |t|
      t.uuid :pos_transaction_id, null: false
      t.integer :line_number, null: false
      t.string :direction, null: false
      t.uuid :product_variant_id, null: false
      t.integer :quantity, null: false
      t.bigint :reference_unit_price_cents, null: false
      t.bigint :selling_unit_price_cents, null: false
      t.bigint :extended_selling_amount_cents, null: false
      t.bigint :line_tax_cents, null: false, default: 0
      t.bigint :line_total_cents, null: false, default: 0
      t.uuid :tax_class_id, null: false
      t.string :tax_class_code_snapshot, null: false
      t.jsonb :merchandise_snapshot
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_transaction_lines, %i[pos_transaction_id line_number], unique: true
    add_check_constraint :pos_transaction_lines, "quantity > 0", name: "pos_transaction_lines_quantity_positive"
    add_check_constraint :pos_transaction_lines, "direction IN ('sale')", name: "pos_transaction_lines_direction_valid"
    add_foreign_key :pos_transaction_lines, :pos_transactions
    add_foreign_key :pos_transaction_lines, :product_variants
    add_foreign_key :pos_transaction_lines, :tax_classes

    create_uuid_table :pos_line_tax_components do |t|
      t.uuid :pos_transaction_line_id, null: false
      t.uuid :store_tax_id, null: false
      t.string :store_tax_code_snapshot, null: false
      t.string :store_tax_name_snapshot, null: false
      t.decimal :rate_percent, precision: 6, scale: 3, null: false
      t.boolean :applies, null: false
      t.bigint :taxable_basis_cents, null: false
      t.bigint :tax_cents, null: false
      t.integer :calculation_order, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_line_tax_components, %i[pos_transaction_line_id store_tax_id], unique: true, name: "index_pos_line_tax_components_on_line_and_store_tax"
    add_check_constraint :pos_line_tax_components, "taxable_basis_cents >= 0 AND tax_cents >= 0", name: "pos_line_tax_components_nonnegative"
    add_foreign_key :pos_line_tax_components, :pos_transaction_lines
    add_foreign_key :pos_line_tax_components, :store_taxes

    create_uuid_table :pos_tenders do |t|
      t.uuid :pos_transaction_id, null: false
      t.string :tender_type, null: false
      t.string :direction, null: false
      t.bigint :amount_cents, null: false
      t.bigint :amount_presented_cents, null: false
      t.bigint :change_cents, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_check_constraint :pos_tenders, "tender_type IN ('cash')", name: "pos_tenders_type_valid"
    add_check_constraint :pos_tenders, "direction IN ('payment')", name: "pos_tenders_direction_valid"
    add_check_constraint :pos_tenders, "amount_cents >= 0 AND amount_presented_cents >= 0 AND change_cents >= 0", name: "pos_tenders_nonnegative"
    add_foreign_key :pos_tenders, :pos_transactions

    create_uuid_table :pos_operations do |t|
      t.string :command_type, null: false
      t.string :fact_type
      t.integer :schema_version
      t.uuid :source_id, null: false
      t.uuid :idempotency_key, null: false
      t.string :command_payload_hash, null: false
      t.string :envelope_hash
      t.string :status, null: false
      t.timestamptz :lease_expires_at
      t.uuid :pos_transaction_id
      t.uuid :store_id
      t.uuid :register_id
      t.string :producer_client
      t.string :producer_version
      t.jsonb :envelope
      t.timestamptz :originated_at
      t.timestamptz :received_at
      t.timestamptz :posted_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_operations, %i[source_id command_type idempotency_key], unique: true, name: "index_pos_operations_on_scope_key"
    add_check_constraint :pos_operations, "status IN ('in_flight', 'completed', 'failed')", name: "pos_operations_status_valid"
    add_check_constraint :pos_operations, <<~SQL.squish, name: "pos_operations_status_payload_rules"
      (status = 'in_flight' AND lease_expires_at IS NOT NULL AND envelope IS NULL AND envelope_hash IS NULL AND fact_type IS NULL)
      OR (status = 'failed' AND envelope IS NULL AND envelope_hash IS NULL)
      OR (status = 'completed' AND fact_type IS NOT NULL AND schema_version IS NOT NULL AND pos_transaction_id IS NOT NULL AND envelope IS NOT NULL AND envelope_hash IS NOT NULL AND posted_at IS NOT NULL)
    SQL
    add_foreign_key :pos_operations, :pos_transactions
    add_foreign_key :pos_operations, :stores
    add_foreign_key :pos_operations, :registers
  end
end
