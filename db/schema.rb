# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_09_221000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", id: :uuid, default: nil, force: :cascade do |t|
    t.string "action", null: false
    t.string "actor_label", null: false
    t.string "actor_type", null: false
    t.uuid "actor_user_id"
    t.jsonb "after_values"
    t.string "application_version"
    t.jsonb "before_values"
    t.uuid "correlation_id", null: false
    t.timestamptz "created_at", null: false
    t.inet "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.timestamptz "occurred_at", null: false
    t.string "outcome", null: false
    t.string "reason_code"
    t.text "reason_text"
    t.timestamptz "recorded_at", null: false
    t.uuid "store_id"
    t.uuid "subject_id"
    t.string "subject_label"
    t.string "subject_type"
    t.text "user_agent"
    t.uuid "user_session_id"
    t.uuid "workstation_id"
    t.index ["action", "occurred_at"], name: "index_audit_events_on_action_and_occurred_at"
    t.index ["actor_user_id", "occurred_at"], name: "index_audit_events_on_actor_user_id_and_occurred_at"
    t.index ["correlation_id"], name: "index_audit_events_on_correlation_id"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
    t.index ["outcome", "occurred_at"], name: "index_audit_events_on_outcome_and_occurred_at"
    t.index ["store_id", "occurred_at"], name: "index_audit_events_on_store_id_and_occurred_at"
    t.index ["subject_type", "subject_id"], name: "index_audit_events_on_subject_type_and_subject_id"
    t.check_constraint "outcome::text = ANY (ARRAY['succeeded'::character varying, 'failed'::character varying, 'denied'::character varying]::text[])", name: "audit_events_outcome_valid"
  end

  create_table "permissions", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.timestamptz "created_at", null: false
    t.text "description"
    t.string "group_key", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "scope_type", null: false
    t.timestamptz "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
    t.check_constraint "scope_type::text = ANY (ARRAY['global'::character varying, 'store'::character varying, 'either'::character varying]::text[])", name: "permissions_scope_type_valid"
  end

  create_table "role_assignments", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "assigned_by_id", null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "effective_at", null: false
    t.timestamptz "expires_at"
    t.text "revocation_reason"
    t.timestamptz "revoked_at"
    t.uuid "revoked_by_id"
    t.uuid "role_id", null: false
    t.uuid "store_id"
    t.timestamptz "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "role_id", "store_id"], name: "index_role_assignments_unique_store_active", unique: true, where: "((store_id IS NOT NULL) AND (revoked_at IS NULL))"
    t.index ["user_id", "role_id"], name: "index_role_assignments_unique_global_active", unique: true, where: "((store_id IS NULL) AND (revoked_at IS NULL))"
  end

  create_table "role_permissions", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.uuid "granted_by_id", null: false
    t.uuid "permission_id", null: false
    t.uuid "role_id", null: false
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
  end

  create_table "roles", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "assignment_scope", null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "deactivated_at"
    t.uuid "deactivated_by_id"
    t.text "description"
    t.string "key", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.boolean "system_role", default: false, null: false
    t.timestamptz "updated_at", null: false
    t.index "lower((name)::text)", name: "index_roles_on_lower_name", unique: true
    t.index ["key"], name: "index_roles_on_key", unique: true
    t.check_constraint "assignment_scope::text = ANY (ARRAY['global'::character varying, 'store'::character varying, 'either'::character varying]::text[])", name: "roles_assignment_scope_valid"
  end

  create_table "stores", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "city"
    t.string "code", null: false
    t.string "country_code", limit: 2, null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "deactivated_at"
    t.uuid "deactivated_by_id"
    t.string "legal_name"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.string "phone"
    t.string "postal_code"
    t.text "receipt_footer"
    t.text "receipt_header"
    t.string "region_code"
    t.string "san"
    t.string "store_number", null: false
    t.string "street_address_1"
    t.string "street_address_2"
    t.string "timezone", null: false
    t.timestamptz "updated_at", null: false
    t.index "lower((code)::text)", name: "index_stores_on_lower_code", unique: true
    t.index "lower((store_number)::text)", name: "index_stores_on_lower_store_number", unique: true
  end

  create_table "system_settings", id: :uuid, default: nil, force: :cascade do |t|
    t.string "base_currency_code", limit: 3, null: false
    t.timestamptz "created_at", null: false
    t.string "default_country_code", limit: 2, null: false
    t.integer "default_customer_reservation_expiration_days", limit: 2, default: 7, null: false
    t.text "default_receipt_footer"
    t.text "default_receipt_header"
    t.string "default_region_code"
    t.integer "default_supplier_cancellation_days", limit: 2, default: 20, null: false
    t.string "default_timezone", null: false
    t.integer "fiscal_year_start_month", limit: 2, default: 1, null: false
    t.timestamptz "initialized_at"
    t.string "legal_name"
    t.integer "lock_version", default: 0, null: false
    t.string "organization_name", null: false
    t.boolean "singleton_key", default: true, null: false
    t.timestamptz "updated_at", null: false
    t.index ["singleton_key"], name: "index_system_settings_on_singleton_key", unique: true
    t.check_constraint "default_customer_reservation_expiration_days >= 0", name: "system_settings_reservation_days_nonnegative"
    t.check_constraint "default_supplier_cancellation_days >= 0", name: "system_settings_supplier_cancellation_days_nonnegative"
    t.check_constraint "fiscal_year_start_month >= 1 AND fiscal_year_start_month <= 12", name: "system_settings_fiscal_year_start_month_range"
    t.check_constraint "singleton_key = true", name: "system_settings_singleton_key_true"
  end

  create_table "user_sessions", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.timestamptz "expires_at", null: false
    t.inet "ip_address"
    t.timestamptz "last_seen_at", null: false
    t.timestamptz "revoked_at"
    t.uuid "revoked_by_id"
    t.string "token_digest", null: false
    t.text "user_agent"
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["token_digest"], name: "index_user_sessions_on_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_user_sessions_on_user_id_and_revoked_at"
  end

  create_table "users", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "actor_type", default: "human", null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "deactivated_at"
    t.uuid "deactivated_by_id"
    t.string "display_name", null: false
    t.string "email"
    t.integer "failed_sign_in_count", default: 0, null: false
    t.timestamptz "last_signed_in_at"
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "locked_at"
    t.timestamptz "password_changed_at"
    t.string "password_digest"
    t.boolean "password_reset_required", default: false, null: false
    t.timestamptz "updated_at", null: false
    t.string "username", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true, where: "(email IS NOT NULL)"
    t.index "lower((username)::text)", name: "index_users_on_lower_username", unique: true
    t.check_constraint "actor_type::text = ANY (ARRAY['human'::character varying, 'system'::character varying, 'integration'::character varying, 'scheduled_job'::character varying]::text[])", name: "users_actor_type_valid"
    t.check_constraint "failed_sign_in_count >= 0", name: "users_failed_sign_in_count_nonnegative"
  end

  create_table "workstations", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "activated_at"
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "deactivated_at"
    t.uuid "deactivated_by_id"
    t.text "description"
    t.timestamptz "last_seen_at"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.bigint "receipt_sequence", default: 0, null: false
    t.timestamptz "revoked_at"
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "code"], name: "index_workstations_on_store_id_and_code", unique: true
    t.check_constraint "receipt_sequence >= 0", name: "workstations_receipt_sequence_nonnegative"
  end

  add_foreign_key "audit_events", "stores"
  add_foreign_key "audit_events", "user_sessions"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "audit_events", "workstations"
  add_foreign_key "role_assignments", "roles"
  add_foreign_key "role_assignments", "stores"
  add_foreign_key "role_assignments", "users"
  add_foreign_key "role_assignments", "users", column: "assigned_by_id"
  add_foreign_key "role_assignments", "users", column: "revoked_by_id"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "role_permissions", "users", column: "granted_by_id"
  add_foreign_key "roles", "users", column: "deactivated_by_id"
  add_foreign_key "stores", "users", column: "deactivated_by_id"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "revoked_by_id"
  add_foreign_key "users", "users", column: "deactivated_by_id"
  add_foreign_key "workstations", "stores"
  add_foreign_key "workstations", "users", column: "deactivated_by_id"
end
