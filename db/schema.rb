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

ActiveRecord::Schema[8.1].define(version: 2026_08_16_240000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # ShelfSense identifier allocation sequences (not owned by a table column).
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_unit_220_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_sku_221_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_product_222_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"

  create_table "adjustment_reasons", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "allows_individual_tracking", default: true, null: false
    t.boolean "allows_quantity_tracking", default: true, null: false
    t.string "code", null: false
    t.boolean "cost_required_for_increase", default: true, null: false
    t.timestamptz "created_at", null: false
    t.text "description"
    t.string "direction", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.boolean "notes_required", default: false, null: false
    t.boolean "system_protected", default: false, null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_adjustment_reasons_on_code", unique: true
    t.check_constraint "direction::text = ANY (ARRAY['increase'::character varying, 'decrease'::character varying, 'either'::character varying]::text[])", name: "adjustment_reasons_direction_valid"
  end

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
    t.uuid "register_id"
    t.uuid "store_id"
    t.uuid "subject_id"
    t.string "subject_label"
    t.string "subject_type"
    t.text "user_agent"
    t.uuid "user_session_id"
    t.index ["action", "occurred_at"], name: "index_audit_events_on_action_and_occurred_at"
    t.index ["actor_user_id", "occurred_at"], name: "index_audit_events_on_actor_user_id_and_occurred_at"
    t.index ["correlation_id"], name: "index_audit_events_on_correlation_id"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
    t.index ["outcome", "occurred_at"], name: "index_audit_events_on_outcome_and_occurred_at"
    t.index ["store_id", "occurred_at"], name: "index_audit_events_on_store_id_and_occurred_at"
    t.index ["subject_type", "subject_id"], name: "index_audit_events_on_subject_type_and_subject_id"
    t.check_constraint "outcome::text = ANY (ARRAY['succeeded'::character varying::text, 'failed'::character varying::text, 'denied'::character varying::text])", name: "audit_events_outcome_valid"
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
    t.check_constraint "code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "departments_code_format"
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
    t.check_constraint "account_category::text = 'cash'::text AND account_type::text = 'asset'::text OR account_category::text = 'accounts_receivable'::text AND account_type::text = 'asset'::text OR account_category::text = 'inventory'::text AND account_type::text = 'asset'::text OR account_category::text = 'other_current_asset'::text AND account_type::text = 'asset'::text OR account_category::text = 'fixed_asset'::text AND account_type::text = 'asset'::text OR account_category::text = 'accounts_payable'::text AND account_type::text = 'liability'::text OR account_category::text = 'other_current_liability'::text AND account_type::text = 'liability'::text OR account_category::text = 'long_term_liability'::text AND account_type::text = 'liability'::text OR account_category::text = 'equity'::text AND account_type::text = 'equity'::text OR account_category::text = 'sales'::text AND account_type::text = 'revenue'::text OR account_category::text = 'sales_returns'::text AND account_type::text = 'revenue'::text OR account_category::text = 'other_revenue'::text AND account_type::text = 'revenue'::text OR account_category::text = 'cost_of_goods_sold'::text AND account_type::text = 'expense'::text OR account_category::text = 'freight_in'::text AND account_type::text = 'expense'::text OR account_category::text = 'inventory_shrinkage'::text AND account_type::text = 'expense'::text OR account_category::text = 'inventory_adjustment'::text AND account_type::text = 'expense'::text OR account_category::text = 'inventory_write_down'::text AND account_type::text = 'expense'::text OR account_category::text = 'other_expense'::text AND account_type::text = 'expense'::text", name: "gl_accounts_category_matches_type"
    t.check_constraint "account_type::text = ANY (ARRAY['asset'::character varying::text, 'liability'::character varying::text, 'equity'::character varying::text, 'revenue'::character varying::text, 'expense'::character varying::text])", name: "gl_accounts_account_type_valid"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "gl_accounts_parent_not_self"
  end

  create_table "idempotency_operations", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "completed_at"
    t.timestamptz "created_at", null: false
    t.text "error_message"
    t.uuid "idempotency_key", null: false
    t.timestamptz "lease_expires_at"
    t.integer "lock_version", default: 0, null: false
    t.string "operation_type", null: false
    t.string "payload_hash", null: false
    t.uuid "result_id"
    t.jsonb "result_payload", default: {}, null: false
    t.string "result_type"
    t.uuid "source_id", null: false
    t.string "status", default: "in_flight", null: false
    t.timestamptz "updated_at", null: false
    t.index ["source_id", "operation_type", "idempotency_key"], name: "index_idempotency_operations_on_scope_key", unique: true
    t.check_constraint "status::text <> 'in_flight'::text OR lease_expires_at IS NOT NULL", name: "idempotency_operations_in_flight_has_lease"
    t.check_constraint "status::text = ANY (ARRAY['in_flight'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "idempotency_operations_status_valid"
  end

  create_table "identifier_registry", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "identifier_kind", null: false
    t.uuid "inventory_unit_id"
    t.uuid "product_id"
    t.uuid "product_variant_id"
    t.timestamptz "retired_at"
    t.timestamptz "updated_at", null: false
    t.string "value", limit: 13, null: false
    t.index ["inventory_unit_id"], name: "index_identifier_registry_inventory_unit", unique: true, where: "((identifier_kind)::text = 'inventory_unit'::text)"
    t.index ["product_id"], name: "index_identifier_registry_active_product_primary", unique: true, where: "(((identifier_kind)::text = 'product_primary'::text) AND (retired_at IS NULL))"
    t.index ["product_variant_id"], name: "index_identifier_registry_active_variant_industry", unique: true, where: "(((identifier_kind)::text = 'variant_industry'::text) AND (retired_at IS NULL))"
    t.index ["product_variant_id"], name: "index_identifier_registry_variant_sku", unique: true, where: "((identifier_kind)::text = 'variant_sku'::text)"
    t.index ["value"], name: "index_identifier_registry_on_value", unique: true
    t.check_constraint "((product_id IS NOT NULL)::integer + (product_variant_id IS NOT NULL)::integer + (inventory_unit_id IS NOT NULL)::integer) <= 1 AND (retired_at IS NOT NULL OR identifier_kind::text = 'product_primary'::text AND product_id IS NOT NULL AND product_variant_id IS NULL AND inventory_unit_id IS NULL OR (identifier_kind::text = ANY (ARRAY['variant_sku'::character varying, 'variant_industry'::character varying]::text[])) AND product_variant_id IS NOT NULL AND product_id IS NULL AND inventory_unit_id IS NULL OR identifier_kind::text = 'inventory_unit'::text AND inventory_unit_id IS NOT NULL AND product_id IS NULL AND product_variant_id IS NULL)", name: "identifier_registry_owner_matches_kind"
    t.check_constraint "identifier_kind::text = ANY (ARRAY['product_primary'::character varying, 'variant_sku'::character varying, 'variant_industry'::character varying, 'inventory_unit'::character varying]::text[])", name: "identifier_registry_kind_valid"
    t.check_constraint "value::text ~ '^[0-9]{13}$'::text", name: "identifier_registry_value_shape"
  end

  create_table "inventory_adjustments", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "acquisition_unit_cost_cents"
    t.uuid "adjustment_reason_id", null: false
    t.date "business_date", null: false
    t.timestamptz "created_at", null: false
    t.uuid "created_by_id", null: false
    t.uuid "inventory_unit_id"
    t.text "notes"
    t.timestamptz "occurred_at", null: false
    t.timestamptz "posted_at", null: false
    t.uuid "product_variant_id", null: false
    t.integer "quantity_delta", null: false
    t.uuid "reversal_of_id"
    t.timestamptz "reversed_at"
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["reversal_of_id"], name: "index_inventory_adjustments_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["store_id", "product_variant_id", "occurred_at"], name: "idx_on_store_id_product_variant_id_occurred_at_1be029f922"
    t.check_constraint "acquisition_unit_cost_cents IS NULL OR acquisition_unit_cost_cents >= 0", name: "inventory_adjustments_cost_nonnegative"
    t.check_constraint "quantity_delta <> 0", name: "inventory_adjustments_quantity_nonzero"
  end

  create_table "inventory_balances", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.bigint "inventory_value_cents", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "on_hand_quantity", default: 0, null: false
    t.uuid "product_variant_id", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "product_variant_id"], name: "index_inventory_balances_on_store_id_and_product_variant_id", unique: true
    t.check_constraint "inventory_value_cents >= 0", name: "inventory_balances_value_nonnegative"
    t.check_constraint "on_hand_quantity <> 0 OR inventory_value_cents = 0", name: "inventory_balances_zero_qty_zero_value"
    t.check_constraint "on_hand_quantity >= 0", name: "inventory_balances_on_hand_nonnegative"
  end

  create_table "inventory_ledger_entries", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "actor_id", null: false
    t.string "actor_type", null: false
    t.date "business_date", null: false
    t.timestamptz "created_at", null: false
    t.integer "effect_sequence", default: 0, null: false
    t.string "entry_type", null: false
    t.uuid "inventory_unit_id"
    t.timestamptz "occurred_at", null: false
    t.uuid "product_variant_id", null: false
    t.integer "quantity_delta", null: false
    t.uuid "reversal_of_id"
    t.uuid "source_id", null: false
    t.string "source_type", null: false
    t.uuid "store_id", null: false
    t.index ["reversal_of_id"], name: "index_inventory_ledger_entries_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["source_type", "source_id", "effect_sequence"], name: "index_inventory_ledger_entries_on_source_effect", unique: true
    t.index ["store_id", "product_variant_id", "occurred_at"], name: "idx_on_store_id_product_variant_id_occurred_at_f610a1cd86"
    t.check_constraint "effect_sequence >= 0", name: "inventory_ledger_entries_effect_sequence_nonnegative"
    t.check_constraint "quantity_delta <> 0", name: "inventory_ledger_entries_quantity_nonzero"
  end

  create_table "inventory_units", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "acquisition_cost_cents", null: false
    t.bigint "carrying_value_cents", null: false
    t.timestamptz "created_at", null: false
    t.string "lifecycle_state", default: "on_hand", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.uuid "product_variant_id", null: false
    t.bigint "regular_price_cents"
    t.timestamptz "removed_at"
    t.uuid "store_id", null: false
    t.string "unit_identifier", limit: 13, null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "product_variant_id", "lifecycle_state"], name: "idx_on_store_id_product_variant_id_lifecycle_state_7edf9fc8ce"
    t.index ["unit_identifier"], name: "index_inventory_units_on_unit_identifier", unique: true
    t.check_constraint "acquisition_cost_cents >= 0 AND carrying_value_cents >= 0", name: "inventory_units_costs_nonnegative"
    t.check_constraint "lifecycle_state::text = 'on_hand'::text AND removed_at IS NULL OR lifecycle_state::text = 'removed'::text AND removed_at IS NOT NULL", name: "inventory_units_removal_consistency"
    t.check_constraint "lifecycle_state::text = ANY (ARRAY['on_hand'::character varying, 'removed'::character varying]::text[])", name: "inventory_units_lifecycle_valid"
    t.check_constraint "regular_price_cents IS NULL OR regular_price_cents >= 0", name: "inventory_units_regular_price_nonnegative"
    t.check_constraint "unit_identifier::text ~ '^[0-9]{13}$'::text", name: "inventory_units_identifier_shape"
  end

  create_table "inventory_valuation_entries", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "acquisition_unit_cost_cents"
    t.date "business_date", null: false
    t.jsonb "calculation_metadata", default: {}, null: false
    t.timestamptz "created_at", null: false
    t.integer "effect_sequence", default: 0, null: false
    t.string "entry_type", null: false
    t.uuid "inventory_unit_id"
    t.timestamptz "occurred_at", null: false
    t.uuid "product_variant_id", null: false
    t.integer "quantity_delta", null: false
    t.uuid "reversal_of_id"
    t.uuid "source_id", null: false
    t.string "source_type", null: false
    t.uuid "store_id", null: false
    t.string "valuation_method", null: false
    t.bigint "value_delta_cents", null: false
    t.index ["reversal_of_id"], name: "index_inventory_valuation_entries_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["source_type", "source_id", "effect_sequence"], name: "index_inventory_valuation_entries_on_source_effect", unique: true
    t.check_constraint "effect_sequence >= 0", name: "inventory_valuation_entries_effect_sequence_nonnegative"
    t.check_constraint "valuation_method::text = ANY (ARRAY['moving_average'::character varying, 'specific_identification'::character varying]::text[])", name: "inventory_valuation_entries_method_valid"
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
    t.check_constraint "code IS NULL OR code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "merchandise_categories_code_format"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "merchandise_categories_parent_not_self"
  end

  create_table "merchandise_classes", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "buyback_allowed", default: false, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.uuid "default_standard_department_id"
    t.boolean "default_supplier_returnable", default: true, null: false
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
    t.check_constraint "NOT buyback_allowed OR used_merchandise_allowed AND inventory_mode::text = 'inventory'::text", name: "merchandise_classes_buyback_implies_used_inventory"
    t.check_constraint "code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "merchandise_classes_code_format"
    t.check_constraint "inventory_mode::text = ANY (ARRAY['inventory'::character varying::text, 'non_inventory'::character varying::text])", name: "merchandise_classes_inventory_mode_valid"
    t.check_constraint "pricing_method::text = ANY (ARRAY['fixed'::character varying::text, 'list_price'::character varying::text, 'cost_based'::character varying::text, 'open_price'::character varying::text])", name: "merchandise_classes_pricing_method_valid"
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
    t.check_constraint "code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "merchandise_conditions_code_format"
    t.check_constraint "price_adjustment_bps >= 0", name: "merchandise_conditions_price_adjustment_nonnegative"
  end

  create_table "outbox_messages", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "aggregate_id", null: false
    t.string "aggregate_type", null: false
    t.integer "aggregate_version"
    t.integer "attempt_count", default: 0, null: false
    t.uuid "causation_id"
    t.uuid "correlation_id", null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "delivered_at"
    t.string "delivery_status", default: "pending", null: false
    t.string "event_type", null: false
    t.timestamptz "last_attempted_at"
    t.timestamptz "occurred_at", null: false
    t.string "origin", default: "server", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "schema_version", default: 1, null: false
    t.index ["delivery_status", "created_at"], name: "index_outbox_messages_on_delivery_status_and_created_at"
    t.index ["event_type"], name: "index_outbox_messages_on_event_type"
    t.check_constraint "delivery_status::text = ANY (ARRAY['pending'::character varying, 'delivered'::character varying, 'failed'::character varying]::text[])", name: "outbox_messages_delivery_status_valid"
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
    t.check_constraint "scope_type::text = ANY (ARRAY['global'::character varying::text, 'store'::character varying::text, 'either'::character varying::text])", name: "permissions_scope_type_valid"
  end

  create_table "pos_line_tax_components", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "applies", null: false
    t.integer "calculation_order", null: false
    t.timestamptz "created_at", null: false
    t.uuid "pos_transaction_line_id", null: false
    t.decimal "rate_percent", precision: 6, scale: 3, null: false
    t.string "store_tax_code_snapshot", null: false
    t.uuid "store_tax_id", null: false
    t.string "store_tax_name_snapshot", null: false
    t.bigint "tax_cents", null: false
    t.bigint "taxable_basis_cents", null: false
    t.timestamptz "updated_at", null: false
    t.index ["pos_transaction_line_id", "store_tax_id"], name: "index_pos_line_tax_components_on_line_and_store_tax", unique: true
    t.check_constraint "taxable_basis_cents >= 0 AND tax_cents >= 0", name: "pos_line_tax_components_nonnegative"
  end

  create_table "pos_operations", id: :uuid, default: nil, force: :cascade do |t|
    t.string "command_payload_hash", null: false
    t.string "command_type", null: false
    t.timestamptz "created_at", null: false
    t.jsonb "envelope"
    t.string "envelope_hash"
    t.string "fact_type"
    t.uuid "idempotency_key", null: false
    t.timestamptz "lease_expires_at"
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "originated_at"
    t.uuid "pos_transaction_id"
    t.timestamptz "posted_at"
    t.string "producer_client"
    t.string "producer_version"
    t.timestamptz "received_at"
    t.uuid "register_id"
    t.integer "schema_version"
    t.uuid "source_id", null: false
    t.string "status", null: false
    t.uuid "store_id"
    t.timestamptz "updated_at", null: false
    t.index ["source_id", "command_type", "idempotency_key"], name: "index_pos_operations_on_scope_key", unique: true
    t.check_constraint "status::text = 'in_flight'::text AND lease_expires_at IS NOT NULL AND envelope IS NULL AND envelope_hash IS NULL AND fact_type IS NULL OR status::text = 'failed'::text AND envelope IS NULL AND envelope_hash IS NULL OR status::text = 'completed'::text AND fact_type IS NOT NULL AND schema_version IS NOT NULL AND pos_transaction_id IS NOT NULL AND envelope IS NOT NULL AND envelope_hash IS NOT NULL AND posted_at IS NOT NULL", name: "pos_operations_status_payload_rules"
    t.check_constraint "status::text = ANY (ARRAY['in_flight'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "pos_operations_status_valid"
  end

  create_table "pos_reporting_periods", id: :uuid, default: nil, force: :cascade do |t|
    t.date "business_date", null: false
    t.timestamptz "closed_at"
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "opened_at", null: false
    t.uuid "register_id", null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["register_id"], name: "index_pos_reporting_periods_one_open_per_register", unique: true, where: "((status)::text = 'open'::text)"
    t.check_constraint "status::text = 'open'::text AND closed_at IS NULL OR status::text = 'finalized'::text AND closed_at IS NOT NULL", name: "pos_reporting_periods_closed_at_matches_status"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'finalized'::character varying]::text[])", name: "pos_reporting_periods_status_valid"
  end

  create_table "pos_sessions", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "cashier_user_id", null: false
    t.timestamptz "closed_at"
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "opened_at", null: false
    t.uuid "register_id", null: false
    t.uuid "reporting_period_id", null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["register_id"], name: "index_pos_sessions_one_open_per_register", unique: true, where: "((status)::text = 'open'::text)"
    t.check_constraint "status::text = 'open'::text AND closed_at IS NULL OR status::text = 'closed'::text AND closed_at IS NOT NULL", name: "pos_sessions_closed_at_matches_status"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'closed'::character varying]::text[])", name: "pos_sessions_status_valid"
  end

  create_table "pos_tenders", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "amount_presented_cents", null: false
    t.bigint "change_cents", default: 0, null: false
    t.timestamptz "created_at", null: false
    t.string "direction", null: false
    t.uuid "pos_transaction_id", null: false
    t.string "tender_type", null: false
    t.timestamptz "updated_at", null: false
    t.check_constraint "amount_cents >= 0 AND amount_presented_cents >= 0 AND change_cents >= 0", name: "pos_tenders_nonnegative"
    t.check_constraint "direction::text = 'payment'::text", name: "pos_tenders_direction_valid"
    t.check_constraint "tender_type::text = 'cash'::text", name: "pos_tenders_type_valid"
  end

  create_table "pos_transaction_lines", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "direction", null: false
    t.bigint "extended_selling_amount_cents", null: false
    t.integer "line_number", null: false
    t.bigint "line_tax_cents", default: 0, null: false
    t.bigint "line_total_cents", default: 0, null: false
    t.jsonb "merchandise_snapshot"
    t.uuid "pos_transaction_id", null: false
    t.uuid "product_variant_id", null: false
    t.integer "quantity", null: false
    t.bigint "reference_unit_price_cents", null: false
    t.bigint "selling_unit_price_cents", null: false
    t.string "tax_class_code_snapshot", null: false
    t.uuid "tax_class_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["pos_transaction_id", "line_number"], name: "idx_on_pos_transaction_id_line_number_00590a67d2", unique: true
    t.check_constraint "direction::text = 'sale'::text", name: "pos_transaction_lines_direction_valid"
    t.check_constraint "quantity > 0", name: "pos_transaction_lines_quantity_positive"
  end

  create_table "pos_transactions", id: :uuid, default: nil, force: :cascade do |t|
    t.date "business_date"
    t.timestamptz "cancelled_at"
    t.uuid "cashier_user_id", null: false
    t.timestamptz "completed_at"
    t.timestamptz "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "occurred_at"
    t.uuid "pos_session_id", null: false
    t.bigint "receipt_sequence"
    t.uuid "register_id", null: false
    t.string "register_number_snapshot"
    t.uuid "reporting_period_id", null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.string "store_number_snapshot"
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.string "transaction_reference"
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "register_id", "receipt_sequence"], name: "index_pos_transactions_receipt_identity", unique: true, where: "(receipt_sequence IS NOT NULL)"
    t.index ["transaction_reference"], name: "index_pos_transactions_on_transaction_reference", unique: true, where: "(transaction_reference IS NOT NULL)"
    t.check_constraint "status::text = 'working'::text AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL AND completed_at IS NULL AND cancelled_at IS NULL OR status::text = 'completed'::text AND receipt_sequence IS NOT NULL AND store_number_snapshot IS NOT NULL AND register_number_snapshot IS NOT NULL AND completed_at IS NOT NULL AND cancelled_at IS NULL OR status::text = 'cancelled'::text AND receipt_sequence IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL", name: "pos_transactions_status_null_rules"
    t.check_constraint "status::text = ANY (ARRAY['working'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "pos_transactions_status_valid"
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
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'discontinued'::character varying::text])", name: "product_variants_status_valid"
    t.check_constraint "variant_type::text = 'standard'::text AND merchandise_condition_id IS NULL OR variant_type::text = 'used'::text AND merchandise_condition_id IS NOT NULL", name: "product_variants_condition_matches_type"
    t.check_constraint "variant_type::text = ANY (ARRAY['standard'::character varying::text, 'used'::character varying::text])", name: "product_variants_variant_type_valid"
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
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'discontinued'::character varying::text])", name: "products_status_valid"
  end

  create_table "registers", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.timestamptz "created_at", null: false
    t.timestamptz "deactivated_at"
    t.uuid "deactivated_by_id"
    t.text "description"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.bigint "receipt_sequence", default: 0, null: false
    t.string "register_number", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "register_number"], name: "index_registers_on_store_id_and_register_number", unique: true
    t.check_constraint "receipt_sequence >= 0", name: "registers_receipt_sequence_nonnegative"
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
    t.check_constraint "assignment_scope::text = ANY (ARRAY['global'::character varying::text, 'store'::character varying::text, 'either'::character varying::text])", name: "roles_assignment_scope_valid"
  end

  create_table "store_tax_rules", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "applies"
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "store_tax_id", null: false
    t.uuid "tax_class_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_tax_id", "tax_class_id"], name: "index_store_tax_rules_on_store_tax_id_and_tax_class_id", unique: true
  end

  create_table "store_taxes", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "calculation_order", default: 0, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.decimal "rate_percent", precision: 6, scale: 3, null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "code"], name: "index_store_taxes_on_store_id_and_code", unique: true
    t.check_constraint "calculation_order >= 0", name: "store_taxes_calculation_order_nonnegative"
    t.check_constraint "rate_percent >= 0::numeric AND rate_percent <= 100::numeric", name: "store_taxes_rate_percent_range"
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
    t.check_constraint "default_customer_reservation_expiration_days > 0", name: "system_settings_reservation_days_positive"
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
    t.check_constraint "code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "tax_classes_code_format"
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
    t.check_constraint "actor_type::text = ANY (ARRAY['human'::character varying::text, 'system'::character varying::text, 'integration'::character varying::text, 'scheduled_job'::character varying::text])", name: "users_actor_type_valid"
    t.check_constraint "failed_sign_in_count >= 0", name: "users_failed_sign_in_count_nonnegative"
  end

  add_foreign_key "audit_events", "registers"
  add_foreign_key "audit_events", "stores"
  add_foreign_key "audit_events", "user_sessions"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
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
  add_foreign_key "identifier_registry", "inventory_units", on_delete: :nullify
  add_foreign_key "identifier_registry", "product_variants", on_delete: :nullify
  add_foreign_key "identifier_registry", "products", on_delete: :nullify
  add_foreign_key "inventory_adjustments", "adjustment_reasons"
  add_foreign_key "inventory_adjustments", "inventory_adjustments", column: "reversal_of_id"
  add_foreign_key "inventory_adjustments", "inventory_units"
  add_foreign_key "inventory_adjustments", "product_variants"
  add_foreign_key "inventory_adjustments", "stores"
  add_foreign_key "inventory_adjustments", "users", column: "created_by_id"
  add_foreign_key "inventory_balances", "product_variants"
  add_foreign_key "inventory_balances", "stores"
  add_foreign_key "inventory_ledger_entries", "inventory_ledger_entries", column: "reversal_of_id"
  add_foreign_key "inventory_ledger_entries", "inventory_units"
  add_foreign_key "inventory_ledger_entries", "product_variants"
  add_foreign_key "inventory_ledger_entries", "stores"
  add_foreign_key "inventory_units", "product_variants"
  add_foreign_key "inventory_units", "stores"
  add_foreign_key "inventory_valuation_entries", "inventory_units"
  add_foreign_key "inventory_valuation_entries", "inventory_valuation_entries", column: "reversal_of_id"
  add_foreign_key "inventory_valuation_entries", "product_variants"
  add_foreign_key "inventory_valuation_entries", "stores"
  add_foreign_key "merchandise_categories", "merchandise_categories", column: "parent_id"
  add_foreign_key "merchandise_categories", "merchandise_classes", column: "default_merchandise_class_id"
  add_foreign_key "merchandise_classes", "departments", column: "default_standard_department_id"
  add_foreign_key "merchandise_classes", "departments", column: "default_used_department_id"
  add_foreign_key "pos_line_tax_components", "pos_transaction_lines"
  add_foreign_key "pos_line_tax_components", "store_taxes"
  add_foreign_key "pos_operations", "pos_transactions"
  add_foreign_key "pos_operations", "registers"
  add_foreign_key "pos_operations", "stores"
  add_foreign_key "pos_reporting_periods", "registers"
  add_foreign_key "pos_reporting_periods", "stores"
  add_foreign_key "pos_sessions", "pos_reporting_periods", column: "reporting_period_id"
  add_foreign_key "pos_sessions", "registers"
  add_foreign_key "pos_sessions", "stores"
  add_foreign_key "pos_sessions", "users", column: "cashier_user_id"
  add_foreign_key "pos_tenders", "pos_transactions"
  add_foreign_key "pos_transaction_lines", "pos_transactions"
  add_foreign_key "pos_transaction_lines", "product_variants"
  add_foreign_key "pos_transaction_lines", "tax_classes"
  add_foreign_key "pos_transactions", "pos_reporting_periods", column: "reporting_period_id"
  add_foreign_key "pos_transactions", "pos_sessions"
  add_foreign_key "pos_transactions", "registers"
  add_foreign_key "pos_transactions", "stores"
  add_foreign_key "pos_transactions", "users", column: "cashier_user_id"
  add_foreign_key "product_variants", "departments"
  add_foreign_key "product_variants", "merchandise_classes"
  add_foreign_key "product_variants", "merchandise_conditions"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "tax_classes"
  add_foreign_key "products", "merchandise_categories"
  add_foreign_key "registers", "stores"
  add_foreign_key "registers", "users", column: "deactivated_by_id"
  add_foreign_key "role_assignments", "roles"
  add_foreign_key "role_assignments", "stores"
  add_foreign_key "role_assignments", "users"
  add_foreign_key "role_assignments", "users", column: "assigned_by_id"
  add_foreign_key "role_assignments", "users", column: "revoked_by_id"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "role_permissions", "users", column: "granted_by_id"
  add_foreign_key "roles", "users", column: "deactivated_by_id"
  add_foreign_key "store_tax_rules", "store_taxes"
  add_foreign_key "store_tax_rules", "tax_classes"
  add_foreign_key "store_taxes", "stores"
  add_foreign_key "stores", "users", column: "deactivated_by_id"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "revoked_by_id"
  add_foreign_key "users", "users", column: "deactivated_by_id"
end
