# frozen_string_literal: true

class CreatePhase11CashAccountability < ActiveRecord::Migration[8.1]
  def change
    add_column :system_settings, :cash_variance_note_threshold_cents, :bigint, null: false, default: 100
    add_column :system_settings, :cash_variance_approval_threshold_cents, :bigint, null: false, default: 1000
    add_column :system_settings, :cash_paid_out_approval_threshold_cents, :bigint, null: false, default: 5000
    add_check_constraint :system_settings, "cash_variance_note_threshold_cents >= 0",
                         name: "system_settings_cash_note_threshold_nonnegative"
    add_check_constraint :system_settings, "cash_variance_approval_threshold_cents >= 0",
                         name: "system_settings_cash_approval_threshold_nonnegative"
    add_check_constraint :system_settings, "cash_paid_out_approval_threshold_cents >= 0",
                         name: "system_settings_cash_paid_out_threshold_nonnegative"

    add_column :stores, :cash_variance_note_threshold_cents, :bigint
    add_column :stores, :cash_variance_approval_threshold_cents, :bigint
    add_column :stores, :cash_paid_out_approval_threshold_cents, :bigint
    add_check_constraint :stores,
                         "cash_variance_note_threshold_cents IS NULL OR cash_variance_note_threshold_cents >= 0",
                         name: "stores_cash_note_threshold_nonnegative"
    add_check_constraint :stores,
                         "cash_variance_approval_threshold_cents IS NULL OR cash_variance_approval_threshold_cents >= 0",
                         name: "stores_cash_approval_threshold_nonnegative"
    add_check_constraint :stores,
                         "cash_paid_out_approval_threshold_cents IS NULL OR cash_paid_out_approval_threshold_cents >= 0",
                         name: "stores_cash_paid_out_threshold_nonnegative"

    add_column :pos_sessions, :closed_by_user_id, :uuid
    add_column :pos_sessions, :close_reason_code, :string
    add_column :pos_sessions, :close_reason_name_snapshot, :string
    add_index :pos_sessions, :closed_by_user_id
    add_foreign_key :pos_sessions, :users, column: :closed_by_user_id

    create_uuid_table :cash_locations do |t|
      t.uuid :store_id, null: false
      t.string :location_type, null: false
      t.bigint :expected_balance_cents, null: false, default: 0
      t.timestamptz :initialized_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_locations, :store_id, unique: true, where: "location_type = 'safe'",
              name: "index_cash_locations_one_safe_per_store"
    add_index :cash_locations, :store_id, unique: true, where: "location_type = 'deposit_in_transit'",
              name: "index_cash_locations_one_dit_per_store"
    add_foreign_key :cash_locations, :stores
    add_check_constraint :cash_locations, "location_type IN ('safe', 'deposit_in_transit')",
                         name: "cash_locations_type_valid"
    add_check_constraint :cash_locations, "expected_balance_cents >= 0",
                         name: "cash_locations_balance_nonnegative"

    create_uuid_table :cash_activity_reasons do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :operation_kind, null: false
      t.boolean :notes_required, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_activity_reasons, :code, unique: true
    add_check_constraint :cash_activity_reasons,
                         "operation_kind IN ('paid_in', 'paid_out', 'over', 'short', 'reverse')",
                         name: "cash_activity_reasons_kind_valid"

    create_uuid_table :cash_operations do |t|
      t.string :operation_type, null: false
      t.uuid :store_id, null: false
      t.date :business_date, null: false
      t.timestamptz :occurred_at, null: false
      t.uuid :performed_by_id, null: false
      t.uuid :approved_by_id
      t.uuid :pos_session_id
      t.uuid :idempotency_operation_id, null: false
      t.uuid :reversal_of_id
      t.string :reason_code
      t.string :reason_name_snapshot
      t.text :notes
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_operations, :idempotency_operation_id, unique: true
    add_index :cash_operations, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :cash_operations, :store_id
    add_index :cash_operations, :performed_by_id
    add_index :cash_operations, :approved_by_id
    add_index :cash_operations, :pos_session_id
    add_foreign_key :cash_operations, :stores
    add_foreign_key :cash_operations, :users, column: :performed_by_id
    add_foreign_key :cash_operations, :users, column: :approved_by_id
    add_foreign_key :cash_operations, :pos_sessions
    add_foreign_key :cash_operations, :idempotency_operations
    add_foreign_key :cash_operations, :cash_operations, column: :reversal_of_id
    add_check_constraint :cash_operations,
                         "operation_type IN ('initialize_safe', 'transfer', 'paid_in', 'paid_out', 'reconcile', 'reverse')",
                         name: "cash_operations_type_valid"
    add_check_constraint :cash_operations,
                         "approved_by_id IS NULL OR approved_by_id <> performed_by_id",
                         name: "cash_operations_approver_differs"

    create_uuid_table :cash_entries do |t|
      t.uuid :cash_operation_id, null: false
      t.integer :entry_sequence, null: false
      t.bigint :amount_cents, null: false
      t.bigint :balance_after_cents, null: false
      t.uuid :pos_session_id
      t.uuid :cash_location_id
      t.uuid :reversal_of_id
      t.timestamptz :created_at, null: false
    end
    add_index :cash_entries, %i[cash_operation_id entry_sequence], unique: true,
              name: "index_cash_entries_on_operation_and_sequence"
    add_index :cash_entries, :pos_session_id
    add_index :cash_entries, :cash_location_id
    add_index :cash_entries, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_foreign_key :cash_entries, :cash_operations
    add_foreign_key :cash_entries, :pos_sessions
    add_foreign_key :cash_entries, :cash_locations
    add_foreign_key :cash_entries, :cash_entries, column: :reversal_of_id
    add_check_constraint :cash_entries, "entry_sequence >= 0", name: "cash_entries_sequence_nonnegative"
    add_check_constraint :cash_entries, "amount_cents <> 0", name: "cash_entries_amount_nonzero"
    add_check_constraint :cash_entries, "balance_after_cents >= 0", name: "cash_entries_balance_after_nonnegative"
    add_check_constraint :cash_entries,
                         "(pos_session_id IS NOT NULL AND cash_location_id IS NULL) OR (pos_session_id IS NULL AND cash_location_id IS NOT NULL)",
                         name: "cash_entries_target_xor"

    create_uuid_table :cash_counts do |t|
      t.string :purpose, null: false
      t.bigint :total_cents, null: false
      t.bigint :expected_cents_snapshot
      t.integer :location_lock_version_snapshot
      t.uuid :pos_session_id
      t.uuid :cash_location_id
      t.string :status, null: false
      t.uuid :superseded_count_id
      t.timestamptz :created_at, null: false
    end
    add_index :cash_counts, :pos_session_id
    add_index :cash_counts, :cash_location_id
    add_foreign_key :cash_counts, :pos_sessions
    add_foreign_key :cash_counts, :cash_locations
    add_foreign_key :cash_counts, :cash_counts, column: :superseded_count_id
    add_check_constraint :cash_counts,
                         "purpose IN ('session_open', 'session_close', 'safe_reconciliation', 'deposit', 'safe_initialization')",
                         name: "cash_counts_purpose_valid"
    add_check_constraint :cash_counts, "status IN ('discarded', 'accepted')", name: "cash_counts_status_valid"
    add_check_constraint :cash_counts, "total_cents >= 0", name: "cash_counts_total_nonnegative"

    create_uuid_table :cash_count_denomination_lines do |t|
      t.uuid :cash_count_id, null: false
      t.integer :quantity, null: false
      t.bigint :denomination_cents, null: false
      t.timestamptz :created_at, null: false
    end
    add_index :cash_count_denomination_lines, :cash_count_id
    add_foreign_key :cash_count_denomination_lines, :cash_counts
    add_check_constraint :cash_count_denomination_lines, "quantity > 0",
                         name: "cash_count_denomination_lines_quantity_positive"
    add_check_constraint :cash_count_denomination_lines, "denomination_cents > 0",
                         name: "cash_count_denomination_lines_denomination_positive"

    create_uuid_table :cash_transfers do |t|
      t.string :transfer_type, null: false
      t.bigint :amount_cents, null: false
      t.uuid :source_pos_session_id
      t.uuid :source_cash_location_id
      t.uuid :destination_pos_session_id
      t.uuid :destination_cash_location_id
      t.uuid :cash_operation_id, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_transfers, :cash_operation_id, unique: true
    add_index :cash_transfers, :source_pos_session_id
    add_index :cash_transfers, :source_cash_location_id
    add_index :cash_transfers, :destination_pos_session_id
    add_index :cash_transfers, :destination_cash_location_id
    add_foreign_key :cash_transfers, :cash_operations
    add_foreign_key :cash_transfers, :pos_sessions, column: :source_pos_session_id
    add_foreign_key :cash_transfers, :cash_locations, column: :source_cash_location_id
    add_foreign_key :cash_transfers, :pos_sessions, column: :destination_pos_session_id
    add_foreign_key :cash_transfers, :cash_locations, column: :destination_cash_location_id
    add_check_constraint :cash_transfers,
                         "transfer_type IN ('opening_float', 'drop', 'replenishment', 'session_close', 'deposit')",
                         name: "cash_transfers_type_valid"
    add_check_constraint :cash_transfers, "amount_cents > 0", name: "cash_transfers_amount_positive"
    add_check_constraint :cash_transfers,
                         "(source_pos_session_id IS NOT NULL AND source_cash_location_id IS NULL) OR (source_pos_session_id IS NULL AND source_cash_location_id IS NOT NULL)",
                         name: "cash_transfers_source_xor"
    add_check_constraint :cash_transfers,
                         "(destination_pos_session_id IS NOT NULL AND destination_cash_location_id IS NULL) OR (destination_pos_session_id IS NULL AND destination_cash_location_id IS NOT NULL)",
                         name: "cash_transfers_destination_xor"

    create_uuid_table :cash_reconciliations do |t|
      t.string :direction, null: false
      t.bigint :expected_cents, null: false
      t.bigint :counted_cents, null: false
      t.bigint :variance_cents, null: false
      t.uuid :pos_session_id
      t.uuid :cash_location_id
      t.uuid :cash_count_id, null: false
      t.uuid :cash_operation_id, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_reconciliations, :cash_operation_id, unique: true
    add_index :cash_reconciliations, :cash_count_id
    add_index :cash_reconciliations, :pos_session_id
    add_index :cash_reconciliations, :cash_location_id
    add_foreign_key :cash_reconciliations, :cash_operations
    add_foreign_key :cash_reconciliations, :cash_counts
    add_foreign_key :cash_reconciliations, :pos_sessions
    add_foreign_key :cash_reconciliations, :cash_locations
    add_check_constraint :cash_reconciliations, "direction IN ('over', 'short')",
                         name: "cash_reconciliations_direction_valid"
    add_check_constraint :cash_reconciliations, "counted_cents >= 0",
                         name: "cash_reconciliations_counted_nonnegative"
    add_check_constraint :cash_reconciliations, "variance_cents = counted_cents - expected_cents",
                         name: "cash_reconciliations_variance_matches"
    add_check_constraint :cash_reconciliations, "variance_cents <> 0",
                         name: "cash_reconciliations_variance_nonzero"
    add_check_constraint :cash_reconciliations,
                         "(pos_session_id IS NOT NULL AND cash_location_id IS NULL) OR (pos_session_id IS NULL AND cash_location_id IS NOT NULL)",
                         name: "cash_reconciliations_target_xor"

    create_uuid_table :cash_safe_initializations do |t|
      t.uuid :cash_location_id, null: false
      t.uuid :cash_count_id, null: false
      t.bigint :counted_cents, null: false
      t.text :notes
      t.uuid :cash_operation_id, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_safe_initializations, :cash_location_id, unique: true
    add_index :cash_safe_initializations, :cash_operation_id, unique: true
    add_foreign_key :cash_safe_initializations, :cash_locations
    add_foreign_key :cash_safe_initializations, :cash_counts
    add_foreign_key :cash_safe_initializations, :cash_operations
    add_check_constraint :cash_safe_initializations, "counted_cents >= 0",
                         name: "cash_safe_initializations_counted_nonnegative"

    reversible do |dir|
      dir.up { backfill_cash_locations }
    end
  end

  private

  def backfill_cash_locations
    now = Time.current
    select_values("SELECT id FROM stores").each do |store_id|
      %w[safe deposit_in_transit].each do |type|
        execute(ActiveRecord::Base.sanitize_sql_array([
          <<~SQL,
            INSERT INTO cash_locations (
              id, store_id, location_type, expected_balance_cents, initialized_at,
              lock_version, created_at, updated_at
            ) VALUES (?, ?, ?, 0, NULL, 0, ?, ?)
          SQL
          SecureRandom.uuid_v7, store_id, type, now, now
        ]))
      end
    end
  end
end
