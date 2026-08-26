# frozen_string_literal: true

class CreatePhase10CustomerStoredValue < ActiveRecord::Migration[8.1]
  def change
    add_column :system_settings, :stored_value_adjust_credit_approval_threshold_cents, :bigint, null: false, default: 5000
    add_check_constraint :system_settings,
                         "stored_value_adjust_credit_approval_threshold_cents >= 0",
                         name: "system_settings_sv_adjust_threshold_nonnegative"

    create_uuid_table :stored_value_adjustment_reasons do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :allowed_direction, null: false
      t.string :allowed_account_types, array: true, null: false, default: []
      t.boolean :notes_required, null: false, default: false
      t.boolean :approval_required, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :stored_value_adjustment_reasons, :code, unique: true
    add_check_constraint :stored_value_adjustment_reasons,
                         "allowed_direction IN ('credit', 'debit', 'either')",
                         name: "stored_value_adjustment_reasons_direction_valid"

    create_uuid_table :stored_value_adjustments do |t|
      t.uuid :stored_value_account_id, null: false
      t.string :adjustment_direction, null: false
      t.bigint :amount_cents, null: false
      t.uuid :reason_id, null: false
      t.string :reason_code, null: false
      t.string :reason_name_snapshot, null: false
      t.text :customer_explanation
      t.text :internal_notes
      t.uuid :store_id, null: false
      t.uuid :performed_by_id, null: false
      t.uuid :approved_by_id
      t.uuid :stored_value_operation_id
      t.uuid :idempotency_operation_id, null: false
      t.uuid :reversal_of_id
      t.timestamptz :posted_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :stored_value_adjustments, :stored_value_operation_id, unique: true, where: "stored_value_operation_id IS NOT NULL"
    add_index :stored_value_adjustments, :idempotency_operation_id
    add_index :stored_value_adjustments, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :stored_value_adjustments, :stored_value_account_id
    add_foreign_key :stored_value_adjustments, :stored_value_accounts
    add_foreign_key :stored_value_adjustments, :stored_value_adjustment_reasons, column: :reason_id
    add_foreign_key :stored_value_adjustments, :stores
    add_foreign_key :stored_value_adjustments, :users, column: :performed_by_id
    add_foreign_key :stored_value_adjustments, :users, column: :approved_by_id
    add_foreign_key :stored_value_adjustments, :stored_value_operations
    add_foreign_key :stored_value_adjustments, :idempotency_operations
    add_foreign_key :stored_value_adjustments, :stored_value_adjustments, column: :reversal_of_id
    add_check_constraint :stored_value_adjustments,
                         "adjustment_direction IN ('credit', 'debit')",
                         name: "stored_value_adjustments_direction_valid"
    add_check_constraint :stored_value_adjustments,
                         "amount_cents > 0",
                         name: "stored_value_adjustments_amount_positive"
    add_check_constraint :stored_value_adjustments,
                         "approved_by_id IS NULL OR approved_by_id <> performed_by_id",
                         name: "stored_value_adjustments_approver_differs"

    create_uuid_table :stored_value_transfers do |t|
      t.string :transfer_type, null: false
      t.uuid :from_account_id, null: false
      t.uuid :to_account_id, null: false
      t.bigint :amount_cents, null: false
      t.uuid :source_customer_id
      t.uuid :survivor_customer_id
      t.string :reason_code
      t.string :reason_name_snapshot
      t.text :notes
      t.uuid :performed_by_id, null: false
      t.uuid :approved_by_id
      t.uuid :stored_value_operation_id
      t.timestamptz :posted_at, null: false
      t.uuid :reversal_of_id
      t.uuid :merge_idempotency_operation_id
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :stored_value_transfers, :stored_value_operation_id, unique: true, where: "stored_value_operation_id IS NOT NULL"
    add_index :stored_value_transfers, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :stored_value_transfers, :from_account_id
    add_index :stored_value_transfers, :to_account_id
    add_foreign_key :stored_value_transfers, :stored_value_accounts, column: :from_account_id
    add_foreign_key :stored_value_transfers, :stored_value_accounts, column: :to_account_id
    add_foreign_key :stored_value_transfers, :customers, column: :source_customer_id
    add_foreign_key :stored_value_transfers, :customers, column: :survivor_customer_id
    add_foreign_key :stored_value_transfers, :users, column: :performed_by_id
    add_foreign_key :stored_value_transfers, :users, column: :approved_by_id
    add_foreign_key :stored_value_transfers, :stored_value_operations
    add_foreign_key :stored_value_transfers, :stored_value_transfers, column: :reversal_of_id
    add_foreign_key :stored_value_transfers, :idempotency_operations, column: :merge_idempotency_operation_id
    add_check_constraint :stored_value_transfers,
                         "transfer_type IN ('customer_merge', 'administrative', 'account_consolidation')",
                         name: "stored_value_transfers_type_valid"
    add_check_constraint :stored_value_transfers,
                         "amount_cents > 0",
                         name: "stored_value_transfers_amount_positive"
    add_check_constraint :stored_value_transfers,
                         "from_account_id <> to_account_id",
                         name: "stored_value_transfers_accounts_differ"
    add_check_constraint :stored_value_transfers,
                         "approved_by_id IS NULL OR approved_by_id <> performed_by_id",
                         name: "stored_value_transfers_approver_differs"
  end
end
