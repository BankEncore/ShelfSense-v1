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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # ShelfSense identifier allocation sequences (not owned by a table column).
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_sku_221_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_product_222_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"

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

  create_table "departments", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.uuid "cost_of_goods_sold_gl_account_id"
    t.timestamptz "created_at", null: false
    t.integer "default_target_margin_bps"
    t.uuid "default_tax_class_id", null: false
    t.string "department_number"
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.uuid "freight_in_gl_account_id"
    t.uuid "inventory_adjustment_gain_gl_account_id"
    t.uuid "inventory_adjustment_loss_gl_account_id"
    t.uuid "inventory_asset_gl_account_id"
    t.uuid "inventory_shrinkage_gl_account_id"
    t.uuid "inventory_write_down_gl_account_id"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.uuid "receiving_clearing_gl_account_id"
    t.uuid "sales_returns_gl_account_id"
    t.uuid "sales_revenue_gl_account_id"
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_departments_on_code", unique: true
    t.index ["cost_of_goods_sold_gl_account_id"], name: "index_departments_on_cost_of_goods_sold_gl_account_id"
    t.index ["department_number"], name: "index_departments_on_department_number", unique: true, where: "(department_number IS NOT NULL)"
    t.index ["freight_in_gl_account_id"], name: "index_departments_on_freight_in_gl_account_id"
    t.index ["inventory_adjustment_gain_gl_account_id"], name: "index_departments_on_inventory_adjustment_gain_gl_account_id"
    t.index ["inventory_adjustment_loss_gl_account_id"], name: "index_departments_on_inventory_adjustment_loss_gl_account_id"
    t.index ["inventory_asset_gl_account_id"], name: "index_departments_on_inventory_asset_gl_account_id"
    t.index ["inventory_shrinkage_gl_account_id"], name: "index_departments_on_inventory_shrinkage_gl_account_id"
    t.index ["inventory_write_down_gl_account_id"], name: "index_departments_on_inventory_write_down_gl_account_id"
    t.index ["receiving_clearing_gl_account_id"], name: "index_departments_on_receiving_clearing_gl_account_id"
    t.index ["sales_returns_gl_account_id"], name: "index_departments_on_sales_returns_gl_account_id"
    t.index ["sales_revenue_gl_account_id"], name: "index_departments_on_sales_revenue_gl_account_id"
    t.check_constraint "default_target_margin_bps IS NULL OR default_target_margin_bps >= 0 AND default_target_margin_bps < 10000", name: "departments_margin_bps_range"
  end

  create_table "gl_accounts", id: :uuid, default: nil, force: :cascade do |t|
    t.string "account_category", null: false
    t.string "account_number", null: false
    t.string "account_type", null: false
    t.boolean "active", default: true, null: false
    t.timestamptz "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.uuid "parent_id"
    t.boolean "posting_allowed", default: true, null: false
    t.timestamptz "updated_at", null: false
    t.index ["account_number"], name: "index_gl_accounts_on_account_number", unique: true
    t.index ["active", "account_number"], name: "index_gl_accounts_on_active_and_account_number"
    t.index ["parent_id"], name: "index_gl_accounts_on_parent_id"
    t.check_constraint "account_type::text = ANY (ARRAY['asset'::character varying, 'liability'::character varying, 'equity'::character varying, 'revenue'::character varying, 'expense'::character varying]::text[])", name: "gl_accounts_account_type_valid"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "gl_accounts_parent_not_self"
  end

  create_table "identifier_registry", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "identifier_kind", null: false
    t.uuid "product_id"
    t.uuid "product_variant_id"
    t.timestamptz "retired_at"
    t.timestamptz "updated_at", null: false
    t.string "value", limit: 13, null: false
    t.index ["product_id"], name: "index_identifier_registry_active_product_primary", unique: true, where: "(((identifier_kind)::text = 'product_primary'::text) AND (retired_at IS NULL))"
    t.index ["product_variant_id"], name: "index_identifier_registry_active_variant_industry", unique: true, where: "(((identifier_kind)::text = 'variant_industry'::text) AND (retired_at IS NULL))"
    t.index ["product_variant_id"], name: "index_identifier_registry_variant_sku", unique: true, where: "((identifier_kind)::text = 'variant_sku'::text)"
    t.index ["value"], name: "index_identifier_registry_on_value", unique: true
    t.check_constraint "identifier_kind::text <> 'product_primary'::text OR product_id IS NOT NULL OR retired_at IS NOT NULL", name: "identifier_registry_product_primary_owner"
    t.check_constraint "identifier_kind::text = ANY (ARRAY['product_primary'::character varying, 'variant_sku'::character varying, 'variant_industry'::character varying]::text[])", name: "identifier_registry_kind_valid"
    t.check_constraint "retired_at IS NOT NULL OR ((product_id IS NOT NULL)::integer + (product_variant_id IS NOT NULL)::integer) = 1", name: "identifier_registry_active_requires_one_owner"
    t.check_constraint "value::text ~ '^[0-9]{13}$'::text", name: "identifier_registry_value_shape"
  end

  create_table "merchandise_categories", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code"
    t.timestamptz "created_at", null: false
    t.uuid "default_merchandise_class_id"
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.uuid "parent_id"
    t.timestamptz "updated_at", null: false
    t.index "lower((name)::text)", name: "index_merchandise_categories_root_name", unique: true, where: "(parent_id IS NULL)"
    t.index "parent_id, lower((name)::text)", name: "index_merchandise_categories_sibling_name", unique: true, where: "(parent_id IS NOT NULL)"
    t.index ["code"], name: "index_merchandise_categories_on_code", unique: true, where: "(code IS NOT NULL)"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "merchandise_categories_parent_not_self"
  end

  create_table "merchandise_classes", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "buyback_allowed", default: false, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.boolean "default_returnable", default: true, null: false
    t.uuid "default_standard_department_id"
    t.uuid "default_used_department_id"
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.string "inventory_mode", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.string "pricing_method", null: false
    t.timestamptz "updated_at", null: false
    t.boolean "used_merchandise_allowed", default: false, null: false
    t.index ["code"], name: "index_merchandise_classes_on_code", unique: true
    t.check_constraint "inventory_mode::text = ANY (ARRAY['inventory'::character varying, 'non_inventory'::character varying]::text[])", name: "merchandise_classes_inventory_mode_valid"
    t.check_constraint "pricing_method::text = ANY (ARRAY['fixed'::character varying, 'list_price'::character varying, 'cost_based'::character varying, 'open_price'::character varying]::text[])", name: "merchandise_classes_pricing_method_valid"
  end

  create_table "merchandise_conditions", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.integer "price_adjustment_bps", default: 10000, null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_merchandise_conditions_on_code", unique: true
    t.check_constraint "price_adjustment_bps >= 0", name: "merchandise_conditions_price_adjustment_nonnegative"
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

  create_table "product_variants", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.uuid "department_id"
    t.string "industry_identifier", limit: 13
    t.integer "lock_version", default: 0, null: false
    t.uuid "merchandise_class_id"
    t.uuid "merchandise_condition_id"
    t.string "name"
    t.string "option_value_1"
    t.string "option_value_2"
    t.uuid "product_id", null: false
    t.bigint "regular_price_cents"
    t.string "sku", limit: 13, null: false
    t.string "status", default: "draft", null: false
    t.uuid "tax_class_id"
    t.timestamptz "updated_at", null: false
    t.string "variant_type", null: false
    t.index ["department_id"], name: "index_product_variants_on_department_id"
    t.index ["industry_identifier"], name: "index_product_variants_on_industry_identifier", unique: true, where: "(industry_identifier IS NOT NULL)"
    t.index ["merchandise_class_id"], name: "index_product_variants_on_merchandise_class_id"
    t.index ["merchandise_condition_id"], name: "index_product_variants_on_merchandise_condition_id"
    t.index ["product_id", "status"], name: "index_product_variants_on_product_id_and_status"
    t.index ["product_id", "variant_type"], name: "index_product_variants_on_product_id_and_variant_type"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.index ["tax_class_id"], name: "index_product_variants_on_tax_class_id"
    t.check_constraint "industry_identifier IS NULL OR industry_identifier::text ~ '^[0-9]{13}$'::text", name: "product_variants_industry_identifier_shape"
    t.check_constraint "regular_price_cents IS NULL OR regular_price_cents >= 0", name: "product_variants_regular_price_nonnegative"
    t.check_constraint "sku::text ~ '^[0-9]{13}$'::text", name: "product_variants_sku_shape"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'discontinued'::character varying]::text[])", name: "product_variants_status_valid"
    t.check_constraint "variant_type::text = 'standard'::text AND merchandise_condition_id IS NULL OR variant_type::text = 'used'::text AND merchandise_condition_id IS NOT NULL", name: "product_variants_condition_matches_type"
    t.check_constraint "variant_type::text = ANY (ARRAY['standard'::character varying, 'used'::character varying]::text[])", name: "product_variants_variant_type_valid"
  end

  create_table "products", id: :uuid, default: nil, force: :cascade do |t|
    t.string "brand_name"
    t.timestamptz "created_at", null: false
    t.text "description"
    t.bigint "list_price_cents"
    t.integer "lock_version", default: 0, null: false
    t.uuid "merchandise_category_id"
    t.string "name", null: false
    t.string "primary_identifier", limit: 13, null: false
    t.string "product_model"
    t.date "release_date"
    t.string "status", default: "draft", null: false
    t.string "subtitle"
    t.timestamptz "updated_at", null: false
    t.string "variant_option_name_1"
    t.string "variant_option_name_2"
    t.index ["merchandise_category_id"], name: "index_products_on_merchandise_category_id"
    t.index ["primary_identifier"], name: "index_products_on_primary_identifier", unique: true
    t.index ["status", "name"], name: "index_products_on_status_and_name"
    t.check_constraint "list_price_cents IS NULL OR list_price_cents >= 0", name: "products_list_price_nonnegative"
    t.check_constraint "primary_identifier::text ~ '^[0-9]{13}$'::text", name: "products_primary_identifier_shape"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'discontinued'::character varying]::text[])", name: "products_status_valid"
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

  create_table "tax_classes", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_tax_classes_on_code", unique: true
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
  add_foreign_key "departments", "gl_accounts", column: "cost_of_goods_sold_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "freight_in_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "inventory_adjustment_gain_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "inventory_adjustment_loss_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "inventory_asset_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "inventory_shrinkage_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "inventory_write_down_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "receiving_clearing_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "sales_returns_gl_account_id"
  add_foreign_key "departments", "gl_accounts", column: "sales_revenue_gl_account_id"
  add_foreign_key "departments", "tax_classes", column: "default_tax_class_id"
  add_foreign_key "gl_accounts", "gl_accounts", column: "parent_id"
  add_foreign_key "identifier_registry", "product_variants", on_delete: :nullify
  add_foreign_key "identifier_registry", "products", on_delete: :nullify
  add_foreign_key "merchandise_categories", "merchandise_categories", column: "parent_id"
  add_foreign_key "merchandise_categories", "merchandise_classes", column: "default_merchandise_class_id"
  add_foreign_key "merchandise_classes", "departments", column: "default_standard_department_id"
  add_foreign_key "merchandise_classes", "departments", column: "default_used_department_id"
  add_foreign_key "product_variants", "departments"
  add_foreign_key "product_variants", "merchandise_classes"
  add_foreign_key "product_variants", "merchandise_conditions"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "tax_classes"
  add_foreign_key "products", "merchandise_categories"
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
