# frozen_string_literal: true

class CreatePhase10StoredValueCore < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :stored_value_accounts do |t|
      t.string :account_type, null: false
      t.uuid :customer_id
      t.string :currency_code, limit: 3, null: false
      t.bigint :balance_cents, null: false, default: 0
      t.string :status, null: false, default: "active"
      t.timestamptz :opened_at, null: false
      t.timestamptz :closed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :stored_value_accounts, %i[customer_id account_type],
              unique: true,
              where: "customer_id IS NOT NULL AND status <> 'closed'",
              name: "index_stored_value_accounts_one_open_per_customer_type"
    add_index :stored_value_accounts, :customer_id
    add_foreign_key :stored_value_accounts, :customers
    add_check_constraint :stored_value_accounts,
                         "account_type IN ('store_credit', 'trade_credit', 'gift_card')",
                         name: "stored_value_accounts_type_valid"
    add_check_constraint :stored_value_accounts,
                         "status IN ('active', 'suspended', 'closed')",
                         name: "stored_value_accounts_status_valid"
    add_check_constraint :stored_value_accounts,
                         "balance_cents >= 0",
                         name: "stored_value_accounts_balance_nonnegative"
    add_check_constraint :stored_value_accounts,
                         "char_length(currency_code) = 3",
                         name: "stored_value_accounts_currency_length"
    add_check_constraint :stored_value_accounts,
                         "(account_type IN ('store_credit', 'trade_credit') AND customer_id IS NOT NULL) OR (account_type = 'gift_card' AND customer_id IS NULL)",
                         name: "stored_value_accounts_customer_matches_type"
    add_check_constraint :stored_value_accounts,
                         "(status <> 'closed' AND closed_at IS NULL) OR (status = 'closed' AND closed_at IS NOT NULL AND balance_cents = 0)",
                         name: "stored_value_accounts_closed_consistency"

    create_uuid_table :stored_value_operations do |t|
      t.string :operation_type, null: false
      t.uuid :store_id, null: false
      t.date :business_date, null: false
      t.timestamptz :occurred_at, null: false
      t.uuid :performed_by_id, null: false
      t.uuid :pos_session_id
      t.uuid :idempotency_operation_id, null: false
      t.uuid :reversal_of_id
      t.string :reason_code
      t.string :reason_name_snapshot
      t.text :notes
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :stored_value_operations, :idempotency_operation_id, unique: true
    add_index :stored_value_operations, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :stored_value_operations, :store_id
    add_index :stored_value_operations, :performed_by_id
    add_index :stored_value_operations, :pos_session_id
    add_foreign_key :stored_value_operations, :stores
    add_foreign_key :stored_value_operations, :users, column: :performed_by_id
    add_foreign_key :stored_value_operations, :pos_sessions
    add_foreign_key :stored_value_operations, :idempotency_operations
    add_foreign_key :stored_value_operations, :stored_value_operations, column: :reversal_of_id
    add_check_constraint :stored_value_operations,
                         "operation_type IN ('issue', 'activate', 'reload', 'redeem', 'refund', 'cash_out', 'transfer', 'adjust', 'reverse')",
                         name: "stored_value_operations_type_valid"

    create_uuid_table :stored_value_entries do |t|
      t.uuid :stored_value_operation_id, null: false
      t.uuid :stored_value_account_id, null: false
      t.integer :entry_sequence, null: false
      t.bigint :amount_cents, null: false
      t.bigint :balance_after_cents, null: false
      t.uuid :reversal_of_id
      t.timestamptz :created_at, null: false
    end
    add_index :stored_value_entries, %i[stored_value_operation_id entry_sequence],
              unique: true,
              name: "index_stored_value_entries_on_operation_and_sequence"
    add_index :stored_value_entries, :stored_value_account_id
    add_index :stored_value_entries, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_foreign_key :stored_value_entries, :stored_value_operations
    add_foreign_key :stored_value_entries, :stored_value_accounts
    add_foreign_key :stored_value_entries, :stored_value_entries, column: :reversal_of_id
    add_check_constraint :stored_value_entries,
                         "entry_sequence >= 0",
                         name: "stored_value_entries_sequence_nonnegative"
    add_check_constraint :stored_value_entries,
                         "amount_cents <> 0",
                         name: "stored_value_entries_amount_nonzero"
    add_check_constraint :stored_value_entries,
                         "balance_after_cents >= 0",
                         name: "stored_value_entries_balance_after_nonnegative"
  end
end
