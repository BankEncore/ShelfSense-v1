# frozen_string_literal: true

class CreatePhase1Foundation < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :users do |t|
      t.string :username, null: false
      t.string :email
      t.string :display_name, null: false
      t.string :actor_type, null: false, default: "human"
      t.string :password_digest
      t.boolean :active, null: false, default: true
      t.timestamptz :password_changed_at
      t.boolean :password_reset_required, null: false, default: false
      t.timestamptz :last_signed_in_at
      t.integer :failed_sign_in_count, null: false, default: 0
      t.timestamptz :locked_at
      t.timestamptz :deactivated_at
      t.uuid :deactivated_by_id
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :users, "lower(username)", unique: true, name: "index_users_on_lower_username"
    add_index :users, "lower(email)", unique: true, where: "email IS NOT NULL", name: "index_users_on_lower_email"
    add_check_constraint :users, "failed_sign_in_count >= 0", name: "users_failed_sign_in_count_nonnegative"
    add_check_constraint :users, "actor_type IN ('human', 'system', 'integration', 'scheduled_job')", name: "users_actor_type_valid"
    add_foreign_key :users, :users, column: :deactivated_by_id

    create_uuid_table :system_settings do |t|
      t.boolean :singleton_key, null: false, default: true
      t.string :organization_name, null: false
      t.string :legal_name
      t.string :base_currency_code, limit: 3, null: false
      t.string :default_timezone, null: false
      t.string :default_country_code, limit: 2, null: false
      t.string :default_region_code
      t.integer :fiscal_year_start_month, limit: 2, null: false, default: 1
      t.integer :default_supplier_cancellation_days, limit: 2, null: false, default: 20
      t.integer :default_customer_reservation_expiration_days, limit: 2, null: false, default: 7
      t.text :default_receipt_header
      t.text :default_receipt_footer
      t.timestamptz :initialized_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :system_settings, :singleton_key, unique: true
    add_check_constraint :system_settings, "singleton_key = true", name: "system_settings_singleton_key_true"
    add_check_constraint :system_settings, "fiscal_year_start_month BETWEEN 1 AND 12", name: "system_settings_fiscal_year_start_month_range"
    add_check_constraint :system_settings, "default_supplier_cancellation_days >= 0", name: "system_settings_supplier_cancellation_days_nonnegative"
    add_check_constraint :system_settings, "default_customer_reservation_expiration_days >= 0", name: "system_settings_reservation_days_nonnegative"

    create_uuid_table :stores do |t|
      t.string :store_number, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.string :legal_name
      t.string :street_address_1
      t.string :street_address_2
      t.string :city
      t.string :region_code
      t.string :postal_code
      t.string :country_code, limit: 2, null: false
      t.string :phone
      t.string :san
      t.string :timezone, null: false
      t.text :receipt_header
      t.text :receipt_footer
      t.boolean :active, null: false, default: true
      t.timestamptz :deactivated_at
      t.uuid :deactivated_by_id
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :stores, "lower(store_number)", unique: true, name: "index_stores_on_lower_store_number"
    add_index :stores, "lower(code)", unique: true, name: "index_stores_on_lower_code"
    add_foreign_key :stores, :users, column: :deactivated_by_id

    create_uuid_table :permissions do |t|
      t.string :key, null: false
      t.string :group_key, null: false
      t.string :name, null: false
      t.text :description
      t.string :scope_type, null: false
      t.boolean :active, null: false, default: true
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :permissions, :key, unique: true
    add_check_constraint :permissions, "scope_type IN ('global', 'store', 'either')", name: "permissions_scope_type_valid"

    create_uuid_table :roles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system_role, null: false, default: false
      t.string :assignment_scope, null: false
      t.boolean :active, null: false, default: true
      t.timestamptz :deactivated_at
      t.uuid :deactivated_by_id
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :roles, :key, unique: true
    add_index :roles, "lower(name)", unique: true, name: "index_roles_on_lower_name"
    add_check_constraint :roles, "assignment_scope IN ('global', 'store', 'either')", name: "roles_assignment_scope_valid"
    add_foreign_key :roles, :users, column: :deactivated_by_id

    create_uuid_table :role_permissions do |t|
      t.uuid :role_id, null: false
      t.uuid :permission_id, null: false
      t.uuid :granted_by_id, null: false
      t.timestamptz :created_at, null: false
    end

    add_index :role_permissions, [ :role_id, :permission_id ], unique: true
    add_foreign_key :role_permissions, :roles
    add_foreign_key :role_permissions, :permissions
    add_foreign_key :role_permissions, :users, column: :granted_by_id

    create_uuid_table :role_assignments do |t|
      t.uuid :user_id, null: false
      t.uuid :role_id, null: false
      t.uuid :store_id
      t.timestamptz :effective_at, null: false
      t.timestamptz :expires_at
      t.uuid :assigned_by_id, null: false
      t.timestamptz :revoked_at
      t.uuid :revoked_by_id
      t.text :revocation_reason
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :role_assignments, [ :user_id, :role_id ],
              unique: true,
              where: "store_id IS NULL AND revoked_at IS NULL",
              name: "index_role_assignments_unique_global_active"
    add_index :role_assignments, [ :user_id, :role_id, :store_id ],
              unique: true,
              where: "store_id IS NOT NULL AND revoked_at IS NULL",
              name: "index_role_assignments_unique_store_active"
    add_foreign_key :role_assignments, :users
    add_foreign_key :role_assignments, :roles
    add_foreign_key :role_assignments, :stores
    add_foreign_key :role_assignments, :users, column: :assigned_by_id
    add_foreign_key :role_assignments, :users, column: :revoked_by_id

    create_uuid_table :workstations do |t|
      t.uuid :store_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.bigint :receipt_sequence, null: false, default: 0
      t.timestamptz :activated_at
      t.timestamptz :revoked_at
      t.timestamptz :deactivated_at
      t.uuid :deactivated_by_id
      t.timestamptz :last_seen_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :workstations, [ :store_id, :code ], unique: true
    add_check_constraint :workstations, "receipt_sequence >= 0", name: "workstations_receipt_sequence_nonnegative"
    add_foreign_key :workstations, :stores
    add_foreign_key :workstations, :users, column: :deactivated_by_id

    create_uuid_table :audit_events do |t|
      t.timestamptz :occurred_at, null: false
      t.timestamptz :recorded_at, null: false
      t.string :actor_type, null: false
      t.uuid :actor_user_id
      t.string :actor_label, null: false
      t.uuid :store_id
      t.uuid :workstation_id
      t.uuid :user_session_id
      t.string :action, null: false
      t.string :outcome, null: false
      t.string :subject_type
      t.uuid :subject_id
      t.string :subject_label
      t.string :reason_code
      t.text :reason_text
      t.uuid :correlation_id, null: false
      t.jsonb :before_values
      t.jsonb :after_values
      t.jsonb :metadata, null: false, default: {}
      t.inet :ip_address
      t.text :user_agent
      t.string :application_version
      t.timestamptz :created_at, null: false
    end

    add_index :audit_events, :occurred_at
    add_index :audit_events, [ :actor_user_id, :occurred_at ]
    add_index :audit_events, [ :store_id, :occurred_at ]
    add_index :audit_events, [ :action, :occurred_at ]
    add_index :audit_events, [ :subject_type, :subject_id ]
    add_index :audit_events, :correlation_id
    add_index :audit_events, [ :outcome, :occurred_at ]
    add_check_constraint :audit_events, "outcome IN ('succeeded', 'failed', 'denied')", name: "audit_events_outcome_valid"
    add_foreign_key :audit_events, :users, column: :actor_user_id
    add_foreign_key :audit_events, :stores
    add_foreign_key :audit_events, :workstations
  end
end
