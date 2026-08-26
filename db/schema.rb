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

ActiveRecord::Schema[8.1].define(version: 2026_08_26_070000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # ShelfSense identifier allocation sequences (not owned by a table column).
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_unit_220_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_sku_221_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"
  execute "CREATE SEQUENCE IF NOT EXISTS shelfsense_product_222_seq AS bigint MINVALUE 0 MAXVALUE 999999999 START WITH 0 INCREMENT BY 1 NO CYCLE"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.check_constraint "direction::text = ANY (ARRAY['increase'::character varying::text, 'decrease'::character varying::text, 'either'::character varying::text])", name: "adjustment_reasons_direction_valid"
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

  create_table "bibliographic_lookup_cache", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.timestamptz "expires_at", null: false
    t.timestamptz "fetched_at", null: false
    t.string "lookup_key", null: false
    t.jsonb "payload", null: false
    t.string "provider", null: false
    t.timestamptz "updated_at", null: false
    t.index ["lookup_key"], name: "index_bibliographic_lookup_cache_on_lookup_key", unique: true
  end

  create_table "customer_request_allocations", id: :uuid, default: nil, force: :cascade do |t|
    t.string "allocation_type", null: false
    t.timestamptz "created_at", null: false
    t.uuid "customer_request_id", null: false
    t.uuid "fulfilled_pos_transaction_line_id"
    t.uuid "inventory_unit_id"
    t.integer "lock_version", default: 0, null: false
    t.uuid "purchase_receipt_line_id"
    t.integer "quantity", default: 1, null: false
    t.text "release_reason"
    t.timestamptz "released_at"
    t.uuid "released_by_id"
    t.string "status", null: false
    t.timestamptz "updated_at", null: false
    t.index ["customer_request_id"], name: "index_customer_request_allocations_on_customer_request_id"
    t.index ["customer_request_id"], name: "index_customer_request_allocations_one_reserved_per_request", unique: true, where: "((status)::text = 'reserved'::text)"
    t.index ["inventory_unit_id"], name: "index_customer_request_allocations_on_inventory_unit_id"
    t.index ["inventory_unit_id"], name: "index_customer_request_allocations_one_reserved_per_unit", unique: true, where: "(((allocation_type)::text = 'used_unit'::text) AND ((status)::text = 'reserved'::text))"
    t.index ["purchase_receipt_line_id"], name: "index_customer_request_allocations_on_purchase_receipt_line_id"
    t.check_constraint "allocation_type::text = 'used_unit'::text AND inventory_unit_id IS NOT NULL OR allocation_type::text = 'standard_quantity'::text AND inventory_unit_id IS NULL", name: "customer_request_allocations_unit_matches_type"
    t.check_constraint "allocation_type::text = ANY (ARRAY['standard_quantity'::character varying::text, 'used_unit'::character varying::text])", name: "customer_request_allocations_type_valid"
    t.check_constraint "quantity = 1", name: "customer_request_allocations_quantity_one"
    t.check_constraint "status::text = ANY (ARRAY['reserved'::character varying::text, 'fulfilled'::character varying::text, 'released'::character varying::text])", name: "customer_request_allocations_status_valid"
  end

  create_table "customer_requests", id: :uuid, default: nil, force: :cascade do |t|
    t.text "cancellation_reason"
    t.timestamptz "cancelled_at"
    t.uuid "cancelled_by_id"
    t.timestamptz "completed_at"
    t.timestamptz "created_at", null: false
    t.uuid "customer_id", null: false
    t.integer "estimated_price_cents"
    t.timestamptz "location_failed_at"
    t.uuid "location_failed_by_id"
    t.text "location_failure_notes"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.integer "number", null: false
    t.uuid "product_variant_id", null: false
    t.integer "requested_quantity", default: 1, null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_requests_on_customer_id"
    t.index ["product_variant_id"], name: "index_customer_requests_on_product_variant_id"
    t.index ["store_id", "number"], name: "index_customer_requests_on_store_id_and_number", unique: true
    t.index ["store_id", "status"], name: "index_customer_requests_on_store_id_and_status"
    t.check_constraint "requested_quantity = 1", name: "customer_requests_quantity_one"
    t.check_constraint "status::text = ANY (ARRAY['pending_location'::character varying::text, 'special_order_pending'::character varying::text, 'ordered'::character varying::text, 'available'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text])", name: "customer_requests_status_valid"
  end

  create_table "customers", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.timestamptz "created_at", null: false
    t.string "display_name", null: false
    t.string "email"
    t.string "email_normalized"
    t.string "family_name"
    t.string "given_name"
    t.integer "lock_version", default: 0, null: false
    t.uuid "merged_into_customer_id"
    t.text "notes"
    t.string "phone"
    t.string "phone_normalized"
    t.string "preferred_contact_method", default: "none", null: false
    t.timestamptz "updated_at", null: false
    t.index ["display_name"], name: "index_customers_on_display_name"
    t.index ["email"], name: "index_customers_on_email"
    t.index ["email_normalized"], name: "index_customers_on_email_normalized"
    t.index ["merged_into_customer_id"], name: "index_customers_on_merged_into_customer_id"
    t.index ["phone"], name: "index_customers_on_phone"
    t.index ["phone_normalized"], name: "index_customers_on_phone_normalized"
    t.check_constraint "merged_into_customer_id IS NULL OR active = false", name: "customers_merged_implies_inactive_check"
    t.check_constraint "merged_into_customer_id IS NULL OR merged_into_customer_id <> id", name: "customers_merged_into_not_self_check"
    t.check_constraint "preferred_contact_method::text = ANY (ARRAY['phone'::character varying::text, 'email'::character varying::text, 'none'::character varying::text])", name: "customers_preferred_contact_method_check"
  end

  create_table "departments", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.uuid "cost_of_goods_sold_gl_account_id"
    t.timestamptz "created_at", null: false
    t.string "department_number", null: false
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
    t.index ["department_number"], name: "index_departments_on_department_number", unique: true
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
  end

  create_table "gift_card_cash_outs", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.uuid "approved_by_id"
    t.date "business_date", null: false
    t.timestamptz "created_at", null: false
    t.uuid "gift_card_id", null: false
    t.uuid "performed_by_id", null: false
    t.boolean "physical_cash_confirmed", default: false, null: false
    t.uuid "physical_cash_confirmed_by_id"
    t.uuid "pos_session_id", null: false
    t.timestamptz "posted_at", null: false
    t.jsonb "program_policy_snapshot", default: {}, null: false
    t.uuid "register_id", null: false
    t.uuid "reversal_of_id"
    t.uuid "store_id", null: false
    t.uuid "stored_value_account_id", null: false
    t.uuid "stored_value_operation_id"
    t.timestamptz "updated_at", null: false
    t.index ["gift_card_id"], name: "index_gift_card_cash_outs_on_gift_card_id"
    t.index ["pos_session_id"], name: "index_gift_card_cash_outs_on_pos_session_id"
    t.index ["register_id"], name: "index_gift_card_cash_outs_on_register_id"
    t.index ["reversal_of_id"], name: "index_gift_card_cash_outs_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["store_id"], name: "index_gift_card_cash_outs_on_store_id"
    t.index ["stored_value_account_id"], name: "index_gift_card_cash_outs_on_stored_value_account_id"
    t.index ["stored_value_operation_id"], name: "index_gift_card_cash_outs_on_operation", unique: true, where: "(stored_value_operation_id IS NOT NULL)"
    t.check_constraint "amount_cents > 0", name: "gift_card_cash_outs_amount_positive"
    t.check_constraint "reversal_of_id IS NULL AND physical_cash_confirmed = false AND physical_cash_confirmed_by_id IS NULL OR reversal_of_id IS NOT NULL AND physical_cash_confirmed = true AND physical_cash_confirmed_by_id IS NOT NULL", name: "gift_card_cash_outs_physical_cash_on_reversal"
  end

  create_table "gift_card_programs", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "cash_out_approval_required", default: false, null: false
    t.string "cash_out_policy", null: false
    t.bigint "cash_out_threshold_cents"
    t.boolean "cash_out_threshold_inclusive", default: true, null: false
    t.string "check_digit_algorithm", default: "luhn", null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "maximum_balance_cents"
    t.bigint "minimum_activation_cents"
    t.string "name", null: false
    t.string "number_authority", null: false
    t.integer "number_length", default: 20, null: false
    t.string "prefix", null: false
    t.boolean "reload_allowed", default: true, null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_gift_card_programs_on_code", unique: true
    t.index ["prefix"], name: "index_gift_card_programs_on_prefix", unique: true
    t.check_constraint "cash_out_policy::text = ANY (ARRAY['prohibited'::character varying, 'permitted_when_eligible'::character varying, 'required_on_request_when_eligible'::character varying]::text[])", name: "gift_card_programs_cash_out_policy_valid"
    t.check_constraint "check_digit_algorithm::text = 'luhn'::text", name: "gift_card_programs_check_digit_valid"
    t.check_constraint "number_authority::text = ANY (ARRAY['system_generated'::character varying, 'manual_external'::character varying]::text[])", name: "gift_card_programs_authority_valid"
    t.check_constraint "number_length = 20", name: "gift_card_programs_length_phase10"
    t.check_constraint "prefix::text ~ '^[0-9]+$'::text", name: "gift_card_programs_prefix_numeric"
  end

  create_table "gift_card_replacements", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.uuid "approved_by_id"
    t.timestamptz "created_at", null: false
    t.text "notes"
    t.uuid "original_gift_card_id", null: false
    t.uuid "performed_by_id", null: false
    t.timestamptz "posted_at", null: false
    t.string "reason_code", null: false
    t.string "reason_name_snapshot", null: false
    t.uuid "replacement_gift_card_id", null: false
    t.uuid "reversal_of_id"
    t.uuid "stored_value_operation_id"
    t.timestamptz "updated_at", null: false
    t.index ["original_gift_card_id"], name: "index_gift_card_replacements_one_effective_per_original", unique: true, where: "(reversal_of_id IS NULL)"
    t.index ["replacement_gift_card_id"], name: "index_gift_card_replacements_on_replacement_gift_card_id"
    t.index ["reversal_of_id"], name: "index_gift_card_replacements_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["stored_value_operation_id"], name: "index_gift_card_replacements_on_stored_value_operation_id", unique: true, where: "(stored_value_operation_id IS NOT NULL)"
    t.check_constraint "amount_cents > 0", name: "gift_card_replacements_amount_positive"
    t.check_constraint "approved_by_id IS NULL OR approved_by_id <> performed_by_id", name: "gift_card_replacements_approver_differs"
    t.check_constraint "original_gift_card_id <> replacement_gift_card_id", name: "gift_card_replacements_cards_differ"
  end

  create_table "gift_cards", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "activated_at", null: false
    t.uuid "activated_store_id", null: false
    t.timestamptz "closed_at"
    t.timestamptz "created_at", null: false
    t.uuid "customer_id"
    t.uuid "gift_card_program_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "number", null: false
    t.string "number_digest", null: false
    t.string "number_last_four", null: false
    t.string "number_prefix", null: false
    t.uuid "replaced_by_id"
    t.string "status", default: "active", null: false
    t.uuid "stored_value_account_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["customer_id"], name: "index_gift_cards_on_customer_id"
    t.index ["gift_card_program_id"], name: "index_gift_cards_on_gift_card_program_id"
    t.index ["number_digest"], name: "index_gift_cards_on_number_digest", unique: true
    t.index ["number_prefix", "number_last_four"], name: "index_gift_cards_on_prefix_and_last_four"
    t.index ["stored_value_account_id"], name: "index_gift_cards_on_stored_value_account_id", unique: true
    t.check_constraint "char_length(number_last_four::text) = 4", name: "gift_cards_last_four_length"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying, 'replaced'::character varying, 'closed'::character varying]::text[])", name: "gift_cards_status_valid"
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
    t.check_constraint "status::text = ANY (ARRAY['in_flight'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "idempotency_operations_status_valid"
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
    t.index ["product_id"], name: "index_identifier_registry_active_product_industry", unique: true, where: "(((identifier_kind)::text = 'product_industry'::text) AND (retired_at IS NULL))"
    t.index ["product_id"], name: "index_identifier_registry_active_product_primary", unique: true, where: "(((identifier_kind)::text = 'product_primary'::text) AND (retired_at IS NULL))"
    t.index ["product_variant_id"], name: "index_identifier_registry_active_variant_industry", unique: true, where: "(((identifier_kind)::text = 'variant_industry'::text) AND (retired_at IS NULL))"
    t.index ["product_variant_id"], name: "index_identifier_registry_variant_sku", unique: true, where: "((identifier_kind)::text = 'variant_sku'::text)"
    t.index ["value"], name: "index_identifier_registry_on_value", unique: true
    t.check_constraint "((product_id IS NOT NULL)::integer + (product_variant_id IS NOT NULL)::integer + (inventory_unit_id IS NOT NULL)::integer) <= 1 AND (retired_at IS NOT NULL OR (identifier_kind::text = ANY (ARRAY['product_primary'::character varying::text, 'product_industry'::character varying::text])) AND product_id IS NOT NULL AND product_variant_id IS NULL AND inventory_unit_id IS NULL OR (identifier_kind::text = ANY (ARRAY['variant_sku'::character varying::text, 'variant_industry'::character varying::text])) AND product_variant_id IS NOT NULL AND product_id IS NULL AND inventory_unit_id IS NULL OR identifier_kind::text = 'inventory_unit'::text AND inventory_unit_id IS NOT NULL AND product_id IS NULL AND product_variant_id IS NULL)", name: "identifier_registry_owner_matches_kind"
    t.check_constraint "identifier_kind::text = ANY (ARRAY['product_primary'::character varying::text, 'product_industry'::character varying::text, 'variant_sku'::character varying::text, 'variant_industry'::character varying::text, 'inventory_unit'::character varying::text])", name: "identifier_registry_kind_valid"
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
    t.check_constraint "quantity_delta <> 0 OR entry_type::text = 'cost_correction'::text", name: "inventory_ledger_entries_quantity_nonzero_or_cost_correction"
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
    t.check_constraint "lifecycle_state::text = ANY (ARRAY['on_hand'::character varying::text, 'removed'::character varying::text])", name: "inventory_units_lifecycle_valid"
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
    t.check_constraint "valuation_method::text = ANY (ARRAY['moving_average'::character varying::text, 'specific_identification'::character varying::text])", name: "inventory_valuation_entries_method_valid"
  end

  create_table "merchandise_categories", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code"
    t.timestamptz "created_at", null: false
    t.uuid "default_standard_merchandise_class_id"
    t.uuid "default_used_merchandise_class_id"
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.uuid "parent_id"
    t.timestamptz "updated_at", null: false
    t.index "lower((name)::text)", name: "index_merchandise_categories_root_name", unique: true, where: "(parent_id IS NULL)"
    t.index "parent_id, lower((name)::text)", name: "index_merchandise_categories_sibling_name", unique: true, where: "(parent_id IS NOT NULL)"
    t.index ["code"], name: "index_merchandise_categories_on_code", unique: true, where: "(code IS NOT NULL)"
    t.index ["default_standard_merchandise_class_id"], name: "idx_on_default_standard_merchandise_class_id_1437b859ed"
    t.index ["default_used_merchandise_class_id"], name: "idx_on_default_used_merchandise_class_id_0ca783adcd"
    t.check_constraint "code IS NULL OR code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "merchandise_categories_code_format"
    t.check_constraint "parent_id IS NULL OR parent_id <> id", name: "merchandise_categories_parent_not_self"
  end

  create_table "merchandise_classes", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "buyback_allowed", default: false, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.string "default_inventory_mode", null: false
    t.string "default_pricing_method", null: false
    t.boolean "default_supplier_returnable", default: true, null: false
    t.uuid "default_tax_class_id", null: false
    t.uuid "department_id", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "merchandise_class_number", null: false
    t.string "name", null: false
    t.integer "target_margin_bps"
    t.timestamptz "updated_at", null: false
    t.boolean "used_merchandise_allowed", default: false, null: false
    t.index ["code"], name: "index_merchandise_classes_on_code", unique: true
    t.index ["default_tax_class_id"], name: "index_merchandise_classes_on_default_tax_class_id"
    t.index ["department_id", "merchandise_class_number"], name: "index_merchandise_classes_on_department_and_number", unique: true
    t.index ["department_id"], name: "index_merchandise_classes_on_department_id"
    t.check_constraint "NOT buyback_allowed OR used_merchandise_allowed AND default_inventory_mode::text = 'inventory'::text", name: "merchandise_classes_buyback_implies_used_inventory"
    t.check_constraint "code::text ~ '^[a-z0-9]+(_[a-z0-9]+)*$'::text", name: "merchandise_classes_code_format"
    t.check_constraint "default_inventory_mode::text = ANY (ARRAY['inventory'::character varying::text, 'non_inventory'::character varying::text])", name: "merchandise_classes_default_inventory_mode_valid"
    t.check_constraint "default_pricing_method::text = ANY (ARRAY['fixed'::character varying::text, 'list_price'::character varying::text, 'cost_based'::character varying::text, 'open_price'::character varying::text])", name: "merchandise_classes_default_pricing_method_valid"
    t.check_constraint "target_margin_bps IS NULL OR target_margin_bps >= 0 AND target_margin_bps < 10000", name: "merchandise_classes_margin_bps_range"
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

  create_table "orders", id: :uuid, default: nil, force: :cascade do |t|
    t.text "cancellation_reason"
    t.timestamptz "cancelled_at"
    t.uuid "cancelled_by_id"
    t.timestamptz "created_at", null: false
    t.uuid "customer_request_id"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.integer "number", null: false
    t.uuid "product_variant_id", null: false
    t.uuid "replaces_order_id"
    t.integer "requested_quantity", null: false
    t.uuid "store_id", null: false
    t.uuid "supplier_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["customer_request_id"], name: "index_orders_on_customer_request_id"
    t.index ["product_variant_id"], name: "index_orders_on_product_variant_id"
    t.index ["replaces_order_id"], name: "index_orders_on_replaces_order_id"
    t.index ["store_id", "number"], name: "index_orders_on_store_id_and_number", unique: true
    t.index ["supplier_id"], name: "index_orders_on_supplier_id"
    t.check_constraint "requested_quantity > 0", name: "orders_requested_quantity_positive"
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
    t.check_constraint "delivery_status::text = ANY (ARRAY['pending'::character varying::text, 'delivered'::character varying::text, 'failed'::character varying::text])", name: "outbox_messages_delivery_status_valid"
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

  create_table "pos_controlled_actions", id: :uuid, default: nil, force: :cascade do |t|
    t.string "action_fingerprint", null: false
    t.string "action_type", null: false
    t.string "approved_by_name_snapshot"
    t.uuid "approved_by_user_id"
    t.timestamptz "created_at", null: false
    t.timestamptz "executed_at", null: false
    t.string "fingerprint_schema_version", null: false
    t.uuid "gift_card_cash_out_id"
    t.jsonb "material_values", default: {}, null: false
    t.string "performed_by_name_snapshot", null: false
    t.uuid "performed_by_user_id", null: false
    t.string "policy_result", null: false
    t.string "policy_version", null: false
    t.uuid "pos_transaction_id"
    t.uuid "pos_transaction_line_id"
    t.string "reason_code", null: false
    t.string "reason_name_snapshot", null: false
    t.text "reason_note"
    t.timestamptz "updated_at", null: false
    t.index ["approved_by_user_id"], name: "index_pos_controlled_actions_on_approved_by_user_id"
    t.index ["gift_card_cash_out_id"], name: "index_pos_controlled_actions_on_cash_out", unique: true, where: "(gift_card_cash_out_id IS NOT NULL)"
    t.index ["performed_by_user_id"], name: "index_pos_controlled_actions_on_performed_by_user_id"
    t.index ["pos_transaction_id", "action_type"], name: "index_pos_controlled_actions_one_post_void", unique: true, where: "((action_type)::text = 'post_void'::text)"
    t.index ["pos_transaction_id"], name: "index_pos_controlled_actions_on_pos_transaction_id"
    t.index ["pos_transaction_line_id", "action_type"], name: "index_pos_controlled_actions_effective_line", unique: true, where: "(pos_transaction_line_id IS NOT NULL)"
    t.index ["pos_transaction_line_id"], name: "index_pos_controlled_actions_on_pos_transaction_line_id"
    t.check_constraint "action_type::text = 'post_void'::text AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NOT NULL AND gift_card_cash_out_id IS NULL OR action_type::text = 'gift_card_cash_out'::text AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NULL AND gift_card_cash_out_id IS NOT NULL OR (action_type::text <> ALL (ARRAY['post_void'::character varying, 'gift_card_cash_out'::character varying]::text[])) AND pos_transaction_line_id IS NOT NULL AND pos_transaction_id IS NOT NULL AND gift_card_cash_out_id IS NULL", name: "pos_controlled_actions_line_scope"
    t.check_constraint "action_type::text = ANY (ARRAY['price_override'::character varying, 'line_discount'::character varying, 'tax_class_override'::character varying, 'unlinked_return'::character varying, 'post_void'::character varying, 'gift_card_cash_out'::character varying]::text[])", name: "pos_controlled_actions_type_valid"
    t.check_constraint "approved_by_user_id IS NULL OR approved_by_user_id <> performed_by_user_id", name: "pos_controlled_actions_approver_not_performer"
    t.check_constraint "policy_result::text = 'approval_required'::text AND approved_by_user_id IS NOT NULL AND approved_by_name_snapshot IS NOT NULL OR policy_result::text = 'direct'::text AND approved_by_user_id IS NULL AND approved_by_name_snapshot IS NULL", name: "pos_controlled_actions_approver_matches_policy"
    t.check_constraint "policy_result::text = ANY (ARRAY['direct'::character varying::text, 'approval_required'::character varying::text])", name: "pos_controlled_actions_policy_valid"
  end

  create_table "pos_gift_card_credential_deliveries", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.timestamptz "delivered_at", null: false
    t.uuid "gift_card_id"
    t.uuid "pos_transaction_id"
    t.timestamptz "updated_at", null: false
    t.index ["gift_card_id"], name: "index_pos_gc_credential_deliveries_on_gift_card", unique: true, where: "(gift_card_id IS NOT NULL)"
    t.index ["pos_transaction_id"], name: "index_pos_gc_credential_deliveries_on_transaction", unique: true
    t.check_constraint "pos_transaction_id IS NOT NULL AND gift_card_id IS NULL OR pos_transaction_id IS NULL AND gift_card_id IS NOT NULL", name: "pos_gc_credential_deliveries_one_subject"
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
    t.index ["store_tax_id"], name: "index_pos_line_tax_components_on_store_tax_id"
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
    t.index ["pos_transaction_id"], name: "index_pos_operations_on_pos_transaction_id"
    t.index ["register_id"], name: "index_pos_operations_on_register_id"
    t.index ["source_id", "command_type", "idempotency_key"], name: "index_pos_operations_on_scope_key", unique: true
    t.index ["store_id"], name: "index_pos_operations_on_store_id"
    t.check_constraint "status::text = 'in_flight'::text AND lease_expires_at IS NOT NULL AND envelope IS NULL AND envelope_hash IS NULL AND fact_type IS NULL OR status::text = 'failed'::text AND envelope IS NULL AND envelope_hash IS NULL OR status::text = 'completed'::text AND fact_type IS NOT NULL AND schema_version IS NOT NULL AND pos_transaction_id IS NOT NULL AND envelope IS NOT NULL AND envelope_hash IS NOT NULL AND posted_at IS NOT NULL", name: "pos_operations_status_payload_rules"
    t.check_constraint "status::text = ANY (ARRAY['in_flight'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text])", name: "pos_operations_status_valid"
  end

  create_table "pos_reporting_periods", id: :uuid, default: nil, force: :cascade do |t|
    t.date "business_date", null: false
    t.timestamptz "closed_at"
    t.timestamptz "created_at", null: false
    t.uuid "finalized_by_user_id"
    t.bigint "finalized_card_payment_cents"
    t.bigint "finalized_card_refund_cents"
    t.bigint "finalized_cash_payment_cents"
    t.bigint "finalized_cash_refund_cents"
    t.bigint "finalized_check_payment_cents"
    t.bigint "finalized_check_refund_cents"
    t.bigint "finalized_closing_count_cents_sum"
    t.bigint "finalized_closing_expected_cash_cents_sum"
    t.bigint "finalized_closing_variance_cents_sum"
    t.bigint "finalized_discount_cents"
    t.bigint "finalized_gift_card_cash_out_cents"
    t.bigint "finalized_gift_card_cash_out_reversal_cents"
    t.bigint "finalized_net_cents"
    t.bigint "finalized_opening_float_cents_sum"
    t.bigint "finalized_other_payment_cents"
    t.bigint "finalized_other_refund_cents"
    t.bigint "finalized_post_void_discount_cents"
    t.bigint "finalized_post_void_merchandise_cents"
    t.bigint "finalized_post_void_net_cents"
    t.bigint "finalized_post_void_tax_cents"
    t.integer "finalized_post_void_transaction_count"
    t.bigint "finalized_return_discount_cents"
    t.bigint "finalized_return_subtotal_cents"
    t.bigint "finalized_return_tax_cents"
    t.bigint "finalized_return_total_cents"
    t.integer "finalized_session_count"
    t.bigint "finalized_stored_value_issuance_cents"
    t.bigint "finalized_stored_value_payment_cents"
    t.bigint "finalized_stored_value_refund_cents"
    t.bigint "finalized_subtotal_cents"
    t.bigint "finalized_tax_cents"
    t.bigint "finalized_total_cents"
    t.integer "finalized_transaction_count"
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "opened_at", null: false
    t.uuid "register_id", null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["finalized_by_user_id"], name: "index_pos_reporting_periods_on_finalized_by_user_id"
    t.index ["register_id"], name: "index_pos_reporting_periods_on_register_id"
    t.index ["register_id"], name: "index_pos_reporting_periods_one_open_per_register", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["store_id"], name: "index_pos_reporting_periods_on_store_id"
    t.check_constraint "finalized_card_payment_cents IS NULL OR finalized_card_payment_cents >= 0", name: "pos_reporting_periods_finalized_card_payment_nonnegative"
    t.check_constraint "finalized_card_refund_cents IS NULL OR finalized_card_refund_cents >= 0", name: "pos_reporting_periods_finalized_card_refund_cents_nonnegative"
    t.check_constraint "finalized_cash_payment_cents IS NULL OR finalized_cash_payment_cents >= 0", name: "pos_reporting_periods_finalized_cash_payment_nonnegative"
    t.check_constraint "finalized_cash_refund_cents IS NULL OR finalized_cash_refund_cents >= 0", name: "pos_reporting_periods_finalized_cash_refund_cents_nonnegative"
    t.check_constraint "finalized_check_payment_cents IS NULL OR finalized_check_payment_cents >= 0", name: "pos_reporting_periods_finalized_check_payment_nonnegative"
    t.check_constraint "finalized_check_refund_cents IS NULL OR finalized_check_refund_cents >= 0", name: "pos_reporting_periods_finalized_check_refund_cents_nonnegative"
    t.check_constraint "finalized_closing_count_cents_sum IS NULL OR finalized_closing_count_cents_sum >= 0", name: "pos_reporting_periods_finalized_closing_count_sum_nonnegative"
    t.check_constraint "finalized_closing_variance_cents_sum IS NULL OR finalized_closing_variance_cents_sum = (finalized_closing_count_cents_sum - finalized_closing_expected_cash_cents_sum)", name: "pos_reporting_periods_finalized_variance_matches_sums"
    t.check_constraint "finalized_discount_cents IS NULL OR finalized_discount_cents >= 0", name: "pos_reporting_periods_finalized_discount_nonnegative"
    t.check_constraint "finalized_gift_card_cash_out_cents IS NULL OR finalized_gift_card_cash_out_cents >= 0", name: "pos_reporting_periods_finalized_gc_cash_out_nonnegative"
    t.check_constraint "finalized_gift_card_cash_out_reversal_cents IS NULL OR finalized_gift_card_cash_out_reversal_cents >= 0", name: "pos_reporting_periods_finalized_gc_cash_out_rev_nonnegative"
    t.check_constraint "finalized_opening_float_cents_sum IS NULL OR finalized_opening_float_cents_sum >= 0", name: "pos_reporting_periods_finalized_opening_float_sum_nonnegative"
    t.check_constraint "finalized_other_payment_cents IS NULL OR finalized_other_payment_cents >= 0", name: "pos_reporting_periods_finalized_other_payment_nonnegative"
    t.check_constraint "finalized_other_refund_cents IS NULL OR finalized_other_refund_cents >= 0", name: "pos_reporting_periods_finalized_other_refund_cents_nonnegative"
    t.check_constraint "finalized_post_void_transaction_count IS NULL OR finalized_post_void_transaction_count >= 0", name: "pos_reporting_periods_finalized_post_void_count_nonnegative"
    t.check_constraint "finalized_return_discount_cents IS NULL OR finalized_return_discount_cents >= 0", name: "pos_reporting_periods_finalized_return_discount_cents_nonnegati"
    t.check_constraint "finalized_return_subtotal_cents IS NULL OR finalized_return_subtotal_cents >= 0", name: "pos_reporting_periods_finalized_return_subtotal_cents_nonnegati"
    t.check_constraint "finalized_return_tax_cents IS NULL OR finalized_return_tax_cents >= 0", name: "pos_reporting_periods_finalized_return_tax_cents_nonnegative"
    t.check_constraint "finalized_return_total_cents IS NULL OR finalized_return_total_cents >= 0", name: "pos_reporting_periods_finalized_return_total_cents_nonnegative"
    t.check_constraint "finalized_session_count IS NULL OR finalized_session_count >= 0", name: "pos_reporting_periods_finalized_session_count_nonnegative"
    t.check_constraint "finalized_stored_value_issuance_cents IS NULL OR finalized_stored_value_issuance_cents >= 0", name: "pos_reporting_periods_finalized_sv_issuance_nonnegative"
    t.check_constraint "finalized_stored_value_payment_cents IS NULL OR finalized_stored_value_payment_cents >= 0", name: "pos_reporting_periods_finalized_sv_payment_nonnegative"
    t.check_constraint "finalized_stored_value_refund_cents IS NULL OR finalized_stored_value_refund_cents >= 0", name: "pos_reporting_periods_finalized_sv_refund_nonnegative"
    t.check_constraint "finalized_subtotal_cents IS NULL OR finalized_subtotal_cents >= 0", name: "pos_reporting_periods_finalized_subtotal_nonnegative"
    t.check_constraint "finalized_tax_cents IS NULL OR finalized_tax_cents >= 0", name: "pos_reporting_periods_finalized_tax_nonnegative"
    t.check_constraint "finalized_total_cents IS NULL OR finalized_total_cents >= 0", name: "pos_reporting_periods_finalized_total_nonnegative"
    t.check_constraint "finalized_transaction_count IS NULL OR finalized_transaction_count >= 0", name: "pos_reporting_periods_finalized_transaction_count_nonnegative"
    t.check_constraint "status::text = 'open'::text AND closed_at IS NULL AND finalized_by_user_id IS NULL AND finalized_transaction_count IS NULL AND finalized_subtotal_cents IS NULL AND finalized_tax_cents IS NULL AND finalized_total_cents IS NULL AND finalized_cash_payment_cents IS NULL AND finalized_session_count IS NULL AND finalized_opening_float_cents_sum IS NULL AND finalized_closing_expected_cash_cents_sum IS NULL AND finalized_closing_count_cents_sum IS NULL AND finalized_closing_variance_cents_sum IS NULL OR status::text = 'finalized'::text AND closed_at IS NOT NULL AND finalized_by_user_id IS NOT NULL AND finalized_transaction_count IS NOT NULL AND finalized_subtotal_cents IS NOT NULL AND finalized_tax_cents IS NOT NULL AND finalized_total_cents IS NOT NULL AND finalized_cash_payment_cents IS NOT NULL AND finalized_session_count IS NOT NULL AND finalized_opening_float_cents_sum IS NOT NULL AND finalized_closing_expected_cash_cents_sum IS NOT NULL AND finalized_closing_count_cents_sum IS NOT NULL AND finalized_closing_variance_cents_sum IS NOT NULL", name: "pos_reporting_periods_closed_at_matches_status"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'finalized'::character varying::text])", name: "pos_reporting_periods_status_valid"
  end

  create_table "pos_sessions", id: :uuid, default: nil, force: :cascade do |t|
    t.uuid "cashier_user_id", null: false
    t.timestamptz "closed_at"
    t.bigint "closing_count_cents"
    t.bigint "closing_expected_cash_cents"
    t.bigint "closing_variance_cents"
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "opened_at", null: false
    t.bigint "opening_float_cents", default: 0, null: false
    t.uuid "register_id", null: false
    t.uuid "reporting_period_id", null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["cashier_user_id"], name: "index_pos_sessions_on_cashier_user_id"
    t.index ["register_id"], name: "index_pos_sessions_on_register_id"
    t.index ["register_id"], name: "index_pos_sessions_one_open_per_register", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["reporting_period_id"], name: "index_pos_sessions_on_reporting_period_id"
    t.index ["store_id"], name: "index_pos_sessions_on_store_id"
    t.check_constraint "closing_count_cents IS NULL OR closing_count_cents >= 0", name: "pos_sessions_closing_count_nonnegative"
    t.check_constraint "closing_variance_cents IS NULL OR closing_variance_cents = (closing_count_cents - closing_expected_cash_cents)", name: "pos_sessions_closing_variance_matches_count"
    t.check_constraint "opening_float_cents >= 0", name: "pos_sessions_opening_float_nonnegative"
    t.check_constraint "status::text = 'open'::text AND closed_at IS NULL AND closing_expected_cash_cents IS NULL AND closing_count_cents IS NULL AND closing_variance_cents IS NULL OR status::text = 'closed'::text AND closed_at IS NOT NULL AND closing_expected_cash_cents IS NOT NULL AND closing_count_cents IS NOT NULL AND closing_variance_cents IS NOT NULL", name: "pos_sessions_closed_at_matches_status"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying::text, 'closed'::character varying::text])", name: "pos_sessions_status_valid"
  end

  create_table "pos_stored_value_issuances", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.timestamptz "created_at", null: false
    t.uuid "gift_card_id"
    t.uuid "gift_card_program_id"
    t.integer "issuance_number", null: false
    t.string "issuance_type", null: false
    t.string "masked_card_snapshot"
    t.string "number_authority", null: false
    t.text "pending_card_number"
    t.string "pending_card_number_digest"
    t.string "pending_card_number_last_four"
    t.string "pending_card_number_prefix"
    t.uuid "pos_transaction_id", null: false
    t.uuid "post_void_source_issuance_id"
    t.uuid "stored_value_operation_id"
    t.timestamptz "updated_at", null: false
    t.index ["gift_card_id"], name: "index_pos_stored_value_issuances_on_gift_card_id"
    t.index ["gift_card_program_id"], name: "index_pos_stored_value_issuances_on_gift_card_program_id"
    t.index ["pending_card_number_digest"], name: "index_pos_sv_issuances_on_pending_digest", unique: true, where: "(pending_card_number_digest IS NOT NULL)"
    t.index ["pos_transaction_id", "issuance_number"], name: "index_pos_sv_issuances_on_txn_and_number", unique: true
    t.index ["post_void_source_issuance_id"], name: "idx_on_post_void_source_issuance_id_8d6ed268d9"
    t.index ["stored_value_operation_id"], name: "index_pos_sv_issuances_on_operation", unique: true, where: "(stored_value_operation_id IS NOT NULL)"
    t.check_constraint "amount_cents > 0", name: "pos_sv_issuances_amount_positive"
    t.check_constraint "issuance_type::text <> 'reload'::text OR gift_card_id IS NOT NULL", name: "pos_sv_issuances_reload_has_card"
    t.check_constraint "issuance_type::text = ANY (ARRAY['activation'::character varying, 'reload'::character varying]::text[])", name: "pos_sv_issuances_type_valid"
    t.check_constraint "number_authority::text = ANY (ARRAY['system_generated'::character varying, 'manual_external'::character varying]::text[])", name: "pos_sv_issuances_authority_valid"
  end

  create_table "pos_stored_value_tender_details", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "destination_mode", null: false
    t.uuid "gift_card_id"
    t.uuid "gift_card_program_id"
    t.string "masked_card_snapshot"
    t.text "pending_card_number"
    t.string "pending_card_number_digest"
    t.string "pending_card_number_last_four"
    t.string "pending_card_number_prefix"
    t.uuid "pos_tender_id", null: false
    t.uuid "stored_value_account_id"
    t.uuid "stored_value_operation_id"
    t.timestamptz "updated_at", null: false
    t.index ["gift_card_id"], name: "index_pos_stored_value_tender_details_on_gift_card_id"
    t.index ["gift_card_program_id"], name: "index_pos_stored_value_tender_details_on_gift_card_program_id"
    t.index ["pending_card_number_digest"], name: "index_pos_sv_tender_details_on_pending_digest", unique: true, where: "(pending_card_number_digest IS NOT NULL)"
    t.index ["pos_tender_id"], name: "index_pos_stored_value_tender_details_on_pos_tender_id", unique: true
    t.index ["stored_value_account_id"], name: "idx_on_stored_value_account_id_33336ce9b4"
    t.index ["stored_value_operation_id"], name: "index_pos_sv_tender_details_on_operation", unique: true, where: "(stored_value_operation_id IS NOT NULL)"
    t.check_constraint "destination_mode::text = ANY (ARRAY['existing_account'::character varying, 'customer_store_credit'::character varying, 'new_gift_card'::character varying]::text[])", name: "pos_sv_tender_details_mode_valid"
  end

  create_table "pos_tenders", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "amount_presented_cents"
    t.string "behavioral_category", null: false
    t.bigint "change_cents"
    t.timestamptz "created_at", null: false
    t.string "direction", null: false
    t.text "external_reference"
    t.uuid "pos_transaction_id", null: false
    t.uuid "post_void_source_tender_id"
    t.string "tender_name", null: false
    t.integer "tender_number", null: false
    t.string "tender_type", null: false
    t.uuid "tender_type_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["pos_transaction_id", "tender_number"], name: "index_pos_tenders_on_transaction_and_number", unique: true
    t.index ["pos_transaction_id"], name: "index_pos_tenders_on_pos_transaction_id"
    t.index ["pos_transaction_id"], name: "index_pos_tenders_one_cash_payment", unique: true, where: "(((behavioral_category)::text = 'cash'::text) AND ((direction)::text = 'payment'::text))"
    t.index ["pos_transaction_id"], name: "index_pos_tenders_one_cash_refund", unique: true, where: "(((behavioral_category)::text = 'cash'::text) AND ((direction)::text = 'refund'::text))"
    t.index ["post_void_source_tender_id"], name: "index_pos_tenders_one_post_void_source", unique: true, where: "(post_void_source_tender_id IS NOT NULL)"
    t.index ["tender_type_id"], name: "index_pos_tenders_on_tender_type_id"
    t.check_constraint "amount_cents >= 0", name: "pos_tenders_amount_nonnegative"
    t.check_constraint "behavioral_category::text = 'cash'::text AND direction::text = 'payment'::text AND amount_presented_cents IS NOT NULL AND change_cents IS NOT NULL AND amount_presented_cents >= 0 AND change_cents >= 0 AND amount_presented_cents = (amount_cents + change_cents) OR behavioral_category::text = 'cash'::text AND direction::text = 'refund'::text AND amount_presented_cents IS NULL AND change_cents IS NULL OR (behavioral_category::text = ANY (ARRAY['card'::character varying, 'check'::character varying, 'other'::character varying, 'stored_value'::character varying]::text[])) AND amount_presented_cents IS NULL AND change_cents IS NULL", name: "pos_tenders_cash_presented_matches"
    t.check_constraint "behavioral_category::text = ANY (ARRAY['cash'::character varying, 'card'::character varying, 'check'::character varying, 'other'::character varying, 'stored_value'::character varying]::text[])", name: "pos_tenders_category_valid"
    t.check_constraint "direction::text = ANY (ARRAY['payment'::character varying::text, 'refund'::character varying::text])", name: "pos_tenders_direction_valid"
    t.check_constraint "post_void_source_tender_id IS NULL OR post_void_source_tender_id <> id", name: "pos_tenders_post_void_source_not_self"
    t.check_constraint "tender_number >= 1", name: "pos_tenders_number_positive"
  end

  create_table "pos_transaction_lines", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.uuid "customer_request_allocation_id"
    t.string "default_tax_class_code_snapshot"
    t.uuid "default_tax_class_id"
    t.string "default_tax_class_name_snapshot"
    t.string "direction", null: false
    t.bigint "extended_selling_amount_cents", null: false
    t.uuid "inventory_unit_id"
    t.integer "line_number", null: false
    t.bigint "line_tax_cents", default: 0, null: false
    t.bigint "line_total_cents", default: 0, null: false
    t.integer "manual_discount_basis_points"
    t.bigint "manual_discount_cents", default: 0, null: false
    t.jsonb "merchandise_snapshot"
    t.bigint "net_merchandise_amount_cents", null: false
    t.uuid "original_transaction_line_id"
    t.uuid "pos_transaction_id", null: false
    t.uuid "post_void_source_line_id"
    t.string "pricing_method_snapshot", default: "configured", null: false
    t.uuid "product_variant_id", null: false
    t.integer "quantity", null: false
    t.bigint "reference_unit_price_cents", null: false
    t.string "return_reason_code"
    t.string "return_reason_name_snapshot"
    t.text "return_reason_note"
    t.bigint "selling_unit_price_cents", null: false
    t.string "tax_class_code_snapshot", null: false
    t.uuid "tax_class_id", null: false
    t.string "tax_class_name_snapshot"
    t.timestamptz "updated_at", null: false
    t.index ["customer_request_allocation_id"], name: "index_pos_transaction_lines_on_customer_request_allocation_id"
    t.index ["default_tax_class_id"], name: "index_pos_transaction_lines_on_default_tax_class_id"
    t.index ["inventory_unit_id"], name: "index_pos_transaction_lines_on_inventory_unit_id"
    t.index ["original_transaction_line_id"], name: "index_pos_transaction_lines_on_original_transaction_line_id"
    t.index ["pos_transaction_id", "line_number"], name: "idx_on_pos_transaction_id_line_number_00590a67d2", unique: true
    t.index ["pos_transaction_id", "original_transaction_line_id"], name: "index_pos_transaction_lines_one_linked_original", unique: true, where: "(original_transaction_line_id IS NOT NULL)"
    t.index ["post_void_source_line_id"], name: "index_pos_transaction_lines_one_post_void_source", unique: true, where: "(post_void_source_line_id IS NOT NULL)"
    t.index ["product_variant_id"], name: "index_pos_transaction_lines_on_product_variant_id"
    t.index ["tax_class_id"], name: "index_pos_transaction_lines_on_tax_class_id"
    t.check_constraint "direction::text = 'sale'::text AND original_transaction_line_id IS NULL AND return_reason_code IS NULL AND return_reason_name_snapshot IS NULL AND return_reason_note IS NULL OR direction::text = 'return'::text AND post_void_source_line_id IS NOT NULL AND original_transaction_line_id IS NULL AND return_reason_code IS NULL AND return_reason_name_snapshot IS NULL AND return_reason_note IS NULL OR direction::text = 'return'::text AND post_void_source_line_id IS NULL AND return_reason_code IS NOT NULL AND return_reason_name_snapshot IS NOT NULL AND (return_reason_code::text = ANY (ARRAY['changed_mind'::character varying::text, 'defective'::character varying::text, 'wrong_item'::character varying::text, 'duplicate_purchase'::character varying::text, 'other'::character varying::text])) AND (return_reason_code::text <> 'other'::text AND return_reason_note IS NULL OR return_reason_code::text = 'other'::text AND return_reason_note IS NOT NULL AND char_length(return_reason_note) >= 1 AND char_length(return_reason_note) <= 200)", name: "pos_transaction_lines_return_reason_rules"
    t.check_constraint "direction::text = ANY (ARRAY['sale'::character varying::text, 'return'::character varying::text])", name: "pos_transaction_lines_direction_valid"
    t.check_constraint "inventory_unit_id IS NULL OR quantity = 1", name: "pos_transaction_lines_unit_quantity_one"
    t.check_constraint "manual_discount_basis_points IS NULL OR manual_discount_basis_points >= 1 AND manual_discount_basis_points <= 10000", name: "pos_transaction_lines_discount_bp_range"
    t.check_constraint "manual_discount_cents >= 0", name: "pos_transaction_lines_discount_nonnegative"
    t.check_constraint "net_merchandise_amount_cents = (extended_selling_amount_cents - manual_discount_cents)", name: "pos_transaction_lines_net_matches_extended_minus_discount"
    t.check_constraint "original_transaction_line_id IS NULL OR direction::text = 'return'::text", name: "pos_transaction_lines_original_requires_return"
    t.check_constraint "original_transaction_line_id IS NULL OR post_void_source_line_id IS NULL", name: "pos_transaction_lines_lineage_exclusive"
    t.check_constraint "post_void_source_line_id IS NULL OR post_void_source_line_id <> id", name: "pos_transaction_lines_post_void_source_not_self"
    t.check_constraint "pricing_method_snapshot::text = ANY (ARRAY['open_price'::character varying::text, 'configured'::character varying::text])", name: "pos_transaction_lines_pricing_method_snapshot_valid"
    t.check_constraint "quantity > 0", name: "pos_transaction_lines_quantity_positive"
  end

  create_table "pos_transactions", id: :uuid, default: nil, force: :cascade do |t|
    t.date "business_date"
    t.timestamptz "cancelled_at"
    t.string "cashier_name_snapshot"
    t.uuid "cashier_user_id", null: false
    t.timestamptz "completed_at"
    t.timestamptz "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.uuid "customer_id"
    t.bigint "discount_cents", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "occurred_at"
    t.uuid "pos_session_id", null: false
    t.uuid "post_void_of_transaction_id"
    t.bigint "receipt_sequence"
    t.uuid "register_id", null: false
    t.integer "register_number_snapshot"
    t.uuid "reporting_period_id", null: false
    t.bigint "return_discount_cents", default: 0, null: false
    t.bigint "return_subtotal_cents", default: 0, null: false
    t.bigint "return_tax_cents", default: 0, null: false
    t.bigint "return_total_cents", default: 0, null: false
    t.bigint "signed_net_cents", default: 0, null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.integer "store_number_snapshot"
    t.bigint "stored_value_issuance_cents", default: 0, null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.string "transaction_reference"
    t.timestamptz "updated_at", null: false
    t.index ["cashier_user_id"], name: "index_pos_transactions_on_cashier_user_id"
    t.index ["customer_id"], name: "index_pos_transactions_on_customer_id"
    t.index ["pos_session_id"], name: "index_pos_transactions_on_pos_session_id"
    t.index ["pos_session_id"], name: "index_pos_transactions_one_working_per_session", unique: true, where: "((status)::text = 'working'::text)"
    t.index ["post_void_of_transaction_id"], name: "index_pos_transactions_one_post_void_per_source", unique: true, where: "(post_void_of_transaction_id IS NOT NULL)"
    t.index ["register_id"], name: "index_pos_transactions_on_register_id"
    t.index ["reporting_period_id"], name: "index_pos_transactions_on_reporting_period_id"
    t.index ["store_id", "business_date", "completed_at", "id"], name: "index_pos_transactions_completed_business_date", order: { completed_at: :desc, id: :desc }, where: "((status)::text = 'completed'::text)"
    t.index ["store_id", "completed_at", "id"], name: "index_pos_transactions_completed_recent", order: { completed_at: :desc, id: :desc }, where: "((status)::text = 'completed'::text)"
    t.index ["store_id", "register_id", "receipt_sequence"], name: "index_pos_transactions_receipt_identity", unique: true, where: "(receipt_sequence IS NOT NULL)"
    t.index ["store_id"], name: "index_pos_transactions_on_store_id"
    t.index ["transaction_reference"], name: "index_pos_transactions_on_transaction_reference", unique: true, where: "(transaction_reference IS NOT NULL)"
    t.check_constraint "post_void_of_transaction_id IS NULL OR post_void_of_transaction_id <> id", name: "pos_transactions_post_void_not_self"
    t.check_constraint "return_subtotal_cents >= 0 AND return_discount_cents >= 0 AND return_tax_cents >= 0 AND return_total_cents >= 0", name: "pos_transactions_return_totals_nonnegative"
    t.check_constraint "return_total_cents = (return_subtotal_cents - return_discount_cents + return_tax_cents)", name: "pos_transactions_return_total_matches_components"
    t.check_constraint "signed_net_cents = (subtotal_cents - discount_cents + tax_cents + stored_value_issuance_cents - return_total_cents)", name: "pos_transactions_signed_net_matches_components"
    t.check_constraint "status::text = 'working'::text AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL AND occurred_at IS NULL AND business_date IS NULL AND completed_at IS NULL AND cancelled_at IS NULL OR status::text = 'completed'::text AND receipt_sequence IS NOT NULL AND store_number_snapshot IS NOT NULL AND register_number_snapshot IS NOT NULL AND occurred_at IS NOT NULL AND business_date IS NOT NULL AND completed_at IS NOT NULL AND cancelled_at IS NULL OR status::text = 'cancelled'::text AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL AND occurred_at IS NULL AND business_date IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL", name: "pos_transactions_status_null_rules"
    t.check_constraint "status::text = ANY (ARRAY['working'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text])", name: "pos_transactions_status_valid"
    t.check_constraint "total_cents = abs(signed_net_cents)", name: "pos_transactions_total_matches_abs_signed_net"
  end

  create_table "product_contributions", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "display_name", null: false
    t.integer "position", default: 0, null: false
    t.uuid "product_id", null: false
    t.string "role", null: false
    t.timestamptz "updated_at", null: false
    t.index ["product_id", "display_name", "role"], name: "index_product_contributions_uniqueness", unique: true
    t.check_constraint "\"position\" >= 0", name: "product_contributions_position_nonnegative"
    t.check_constraint "role::text = ANY (ARRAY['author'::character varying::text, 'editor'::character varying::text, 'illustrator'::character varying::text, 'translator'::character varying::text, 'photographer'::character varying::text, 'narrator'::character varying::text, 'other'::character varying::text])", name: "product_contributions_role_valid"
  end

  create_table "product_forms", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", limit: 2, null: false
    t.timestamptz "created_at", null: false
    t.integer "display_order", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_product_forms_on_code", unique: true
    t.check_constraint "code::text ~ '^[A-Z]{2}$'::text", name: "product_forms_code_format"
  end

  create_table "product_subject_assignments", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.integer "position", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.uuid "product_id", null: false
    t.uuid "subject_heading_id", null: false
    t.uuid "subject_scheme_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["product_id", "subject_heading_id"], name: "index_product_subject_assignments_uniqueness", unique: true
    t.index ["product_id", "subject_scheme_id"], name: "index_product_subject_assignments_primary_per_scheme", unique: true, where: "(\"primary\" = true)"
  end

  create_table "product_variants", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "industry_identifier", limit: 13
    t.string "inventory_mode"
    t.integer "lock_version", default: 0, null: false
    t.uuid "merchandise_class_id"
    t.uuid "merchandise_condition_id"
    t.string "name"
    t.string "option_value_1"
    t.string "option_value_2"
    t.string "pricing_method"
    t.uuid "product_id", null: false
    t.bigint "regular_price_cents"
    t.string "sku", limit: 13, null: false
    t.string "status", default: "draft", null: false
    t.boolean "supplier_returnable"
    t.integer "target_margin_bps"
    t.uuid "tax_class_override_id"
    t.timestamptz "updated_at", null: false
    t.string "variant_type", null: false
    t.index ["industry_identifier"], name: "index_product_variants_on_industry_identifier", unique: true, where: "(industry_identifier IS NOT NULL)"
    t.index ["merchandise_class_id"], name: "index_product_variants_on_merchandise_class_id"
    t.index ["merchandise_condition_id"], name: "index_product_variants_on_merchandise_condition_id"
    t.index ["product_id", "status"], name: "index_product_variants_on_product_id_and_status"
    t.index ["product_id", "variant_type"], name: "index_product_variants_on_product_id_and_variant_type"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.index ["tax_class_override_id"], name: "index_product_variants_on_tax_class_override_id"
    t.check_constraint "industry_identifier IS NULL OR industry_identifier::text ~ '^[0-9]{13}$'::text", name: "product_variants_industry_identifier_shape"
    t.check_constraint "inventory_mode IS NULL OR (inventory_mode::text = ANY (ARRAY['inventory'::character varying::text, 'non_inventory'::character varying::text]))", name: "product_variants_inventory_mode_valid"
    t.check_constraint "pricing_method IS NULL OR (pricing_method::text = ANY (ARRAY['fixed'::character varying::text, 'list_price'::character varying::text, 'cost_based'::character varying::text, 'open_price'::character varying::text]))", name: "product_variants_pricing_method_valid"
    t.check_constraint "regular_price_cents IS NULL OR regular_price_cents >= 0", name: "product_variants_regular_price_nonnegative"
    t.check_constraint "sku::text ~ '^[0-9]{13}$'::text", name: "product_variants_sku_shape"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'discontinued'::character varying::text])", name: "product_variants_status_valid"
    t.check_constraint "target_margin_bps IS NULL OR target_margin_bps >= 0 AND target_margin_bps < 10000", name: "product_variants_margin_bps_range"
    t.check_constraint "variant_type::text = 'standard'::text AND merchandise_condition_id IS NULL OR variant_type::text = 'used'::text AND merchandise_condition_id IS NOT NULL", name: "product_variants_condition_matches_type"
    t.check_constraint "variant_type::text = ANY (ARRAY['standard'::character varying::text, 'used'::character varying::text])", name: "product_variants_variant_type_valid"
  end

  create_table "products", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "bibliographic_applied_at"
    t.timestamptz "bibliographic_fetched_at"
    t.jsonb "bibliographic_field_sources", default: {}, null: false
    t.string "bibliographic_provider"
    t.string "bibliographic_provider_key"
    t.string "binding_legacy"
    t.string "brand_name"
    t.timestamptz "created_at", null: false
    t.text "description"
    t.string "imprint"
    t.string "industry_identifier", limit: 13
    t.string "language_code"
    t.bigint "list_price_cents"
    t.integer "lock_version", default: 0, null: false
    t.string "lookup_code", limit: 64
    t.uuid "merchandise_category_id"
    t.string "name", null: false
    t.integer "page_count"
    t.string "primary_identifier", limit: 13, null: false
    t.uuid "product_form_id"
    t.string "product_model"
    t.date "release_date"
    t.boolean "release_date_approximate", default: false, null: false
    t.string "series_name"
    t.decimal "series_position", precision: 8, scale: 3
    t.string "status", default: "draft", null: false
    t.string "subtitle"
    t.timestamptz "updated_at", null: false
    t.string "variant_option_name_1"
    t.string "variant_option_name_2"
    t.index ["bibliographic_provider_key"], name: "index_products_on_bibliographic_provider_key"
    t.index ["industry_identifier"], name: "index_products_on_industry_identifier", unique: true, where: "(industry_identifier IS NOT NULL)"
    t.index ["lookup_code"], name: "index_products_on_lookup_code", where: "(lookup_code IS NOT NULL)"
    t.index ["merchandise_category_id"], name: "index_products_on_merchandise_category_id"
    t.index ["primary_identifier"], name: "index_products_on_primary_identifier", unique: true
    t.index ["product_form_id"], name: "index_products_on_product_form_id"
    t.index ["status", "name"], name: "index_products_on_status_and_name"
    t.check_constraint "industry_identifier IS NULL OR industry_identifier::text ~ '^[0-9]{13}$'::text", name: "products_industry_identifier_shape"
    t.check_constraint "list_price_cents IS NULL OR list_price_cents >= 0", name: "products_list_price_nonnegative"
    t.check_constraint "lookup_code IS NULL OR lookup_code::text = upper(btrim(lookup_code::text)) AND char_length(lookup_code::text) >= 1 AND char_length(lookup_code::text) <= 64 AND lookup_code::text ~ '^[A-Z0-9._/-]+$'::text", name: "products_lookup_code_canonical"
    t.check_constraint "page_count IS NULL OR page_count > 0", name: "products_page_count_positive"
    t.check_constraint "primary_identifier::text ~ '^[0-9]{13}$'::text", name: "products_primary_identifier_shape"
    t.check_constraint "series_position IS NULL OR series_position >= '-99999.999'::numeric AND series_position <= 99999.999", name: "products_series_position_range"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'active'::character varying::text, 'discontinued'::character varying::text])", name: "products_status_valid"
  end

  create_table "purchase_order_line_cancellations", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.timestamptz "occurred_at", null: false
    t.uuid "purchase_order_line_id", null: false
    t.integer "quantity", null: false
    t.text "reason", null: false
    t.uuid "recorded_by_id", null: false
    t.string "source", null: false
    t.timestamptz "updated_at", null: false
    t.index ["purchase_order_line_id"], name: "idx_on_purchase_order_line_id_5f60c1a484"
    t.index ["recorded_by_id"], name: "index_purchase_order_line_cancellations_on_recorded_by_id"
    t.check_constraint "quantity > 0", name: "purchase_order_line_cancellations_quantity_positive"
    t.check_constraint "source::text = ANY (ARRAY['buyer'::character varying::text, 'supplier'::character varying::text])", name: "purchase_order_line_cancellations_source_valid"
  end

  create_table "purchase_order_line_states", primary_key: "purchase_order_line_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "backordered_quantity", default: 0, null: false
    t.integer "confirmed_quantity"
    t.timestamptz "created_at", null: false
    t.date "expected_on"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.string "supplier_reference"
    t.timestamptz "updated_at", null: false
    t.check_constraint "backordered_quantity >= 0", name: "purchase_order_line_states_backordered_quantity_nonnegative"
    t.check_constraint "confirmed_quantity IS NULL OR confirmed_quantity >= 0", name: "purchase_order_line_states_confirmed_quantity_nonnegative"
  end

  create_table "purchase_order_lines", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.integer "discount_basis_points_snapshot"
    t.integer "expected_unit_cost_cents_snapshot", null: false
    t.text "notes_snapshot"
    t.uuid "order_id", null: false
    t.integer "ordered_quantity", null: false
    t.string "pricing_method_snapshot"
    t.uuid "product_variant_id", null: false
    t.uuid "purchase_order_id", null: false
    t.string "supplier_item_number_snapshot"
    t.integer "supplier_list_price_cents_snapshot"
    t.timestamptz "updated_at", null: false
    t.index ["order_id"], name: "index_purchase_order_lines_on_order_id", unique: true
    t.index ["product_variant_id"], name: "index_purchase_order_lines_on_product_variant_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_lines_on_purchase_order_id"
    t.check_constraint "expected_unit_cost_cents_snapshot >= 0", name: "purchase_order_lines_expected_cost_nonnegative"
    t.check_constraint "ordered_quantity > 0", name: "purchase_order_lines_ordered_quantity_positive"
  end

  create_table "purchase_orders", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "closed_at"
    t.timestamptz "created_at", null: false
    t.integer "document_revision", default: 0, null: false
    t.timestamptz "generated_at"
    t.uuid "generated_by_id"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.integer "number"
    t.timestamptz "sent_at"
    t.uuid "sent_by_id"
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.uuid "supplier_id", null: false
    t.string "transmission_method"
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "number"], name: "index_purchase_orders_on_store_and_number", unique: true, where: "(number IS NOT NULL)"
    t.index ["store_id", "status"], name: "index_purchase_orders_on_store_id_and_status"
    t.index ["store_id", "supplier_id"], name: "index_purchase_orders_one_open_draft_per_store_supplier", unique: true, where: "((status)::text = 'draft'::text)"
    t.index ["supplier_id"], name: "index_purchase_orders_on_supplier_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'sent'::character varying::text, 'closed'::character varying::text, 'cancelled'::character varying::text])", name: "purchase_orders_status_valid"
  end

  create_table "purchase_receipt_line_corrections", id: :uuid, default: nil, force: :cascade do |t|
    t.string "correction_type", null: false
    t.timestamptz "created_at", null: false
    t.uuid "inventory_source_id"
    t.string "inventory_source_type"
    t.uuid "purchase_receipt_line_id", null: false
    t.integer "quantity"
    t.text "reason", null: false
    t.timestamptz "recorded_at", null: false
    t.uuid "recorded_by_id", null: false
    t.timestamptz "updated_at", null: false
    t.bigint "value_delta_cents"
    t.index ["inventory_source_type", "inventory_source_id"], name: "index_prl_corrections_on_inventory_source"
    t.index ["purchase_receipt_line_id"], name: "idx_on_purchase_receipt_line_id_c4b7a21d2e"
    t.index ["recorded_by_id"], name: "index_purchase_receipt_line_corrections_on_recorded_by_id"
    t.check_constraint "correction_type::text = 'cost_correction'::text AND value_delta_cents IS NOT NULL AND value_delta_cents <> 0 OR correction_type::text = 'compensating_adjustment_reference'::text AND value_delta_cents IS NOT NULL OR correction_type::text = 'quantity_reversal'::text", name: "prl_corrections_cost_value_present"
    t.check_constraint "correction_type::text = 'quantity_reversal'::text AND quantity > 0 OR correction_type::text = 'compensating_adjustment_reference'::text AND quantity > 0 OR correction_type::text = 'cost_correction'::text AND quantity IS NULL", name: "prl_corrections_quantity_matches_type"
    t.check_constraint "correction_type::text = ANY (ARRAY['quantity_reversal'::character varying::text, 'cost_correction'::character varying::text, 'compensating_adjustment_reference'::character varying::text])", name: "prl_corrections_type_valid"
  end

  create_table "purchase_receipt_lines", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "actual_unit_cost_cents", null: false
    t.timestamptz "created_at", null: false
    t.integer "matched_quantity", default: 0, null: false
    t.text "notes"
    t.uuid "product_variant_id", null: false
    t.uuid "purchase_order_line_id", null: false
    t.uuid "purchase_receipt_id", null: false
    t.integer "received_quantity", null: false
    t.integer "unplanned_quantity", default: 0, null: false
    t.timestamptz "updated_at", null: false
    t.index ["product_variant_id"], name: "index_purchase_receipt_lines_on_product_variant_id"
    t.index ["purchase_order_line_id"], name: "index_purchase_receipt_lines_on_purchase_order_line_id"
    t.index ["purchase_receipt_id", "purchase_order_line_id"], name: "index_purchase_receipt_lines_on_receipt_and_po_line", unique: true
    t.index ["purchase_receipt_id"], name: "index_purchase_receipt_lines_on_purchase_receipt_id"
    t.check_constraint "(matched_quantity + unplanned_quantity) = received_quantity", name: "purchase_receipt_lines_quantities_add_up"
    t.check_constraint "actual_unit_cost_cents >= 0", name: "purchase_receipt_lines_actual_cost_nonnegative"
    t.check_constraint "matched_quantity >= 0 AND unplanned_quantity >= 0", name: "purchase_receipt_lines_matched_unplanned_nonnegative"
    t.check_constraint "received_quantity > 0", name: "purchase_receipt_lines_received_quantity_positive"
  end

  create_table "purchase_receipts", id: :uuid, default: nil, force: :cascade do |t|
    t.text "charge_notes"
    t.timestamptz "created_at", null: false
    t.integer "freight_cents", default: 0, null: false
    t.integer "handling_cents", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "miscellaneous_charges_cents", default: 0, null: false
    t.text "notes"
    t.integer "number"
    t.timestamptz "posted_at"
    t.uuid "posted_by_id"
    t.timestamptz "received_at", null: false
    t.string "status", null: false
    t.uuid "store_id", null: false
    t.date "supplier_document_date"
    t.string "supplier_document_number"
    t.uuid "supplier_id", null: false
    t.integer "supplier_tax_cents", default: 0, null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "number"], name: "index_purchase_receipts_on_store_and_number", unique: true, where: "(number IS NOT NULL)"
    t.index ["store_id", "status"], name: "index_purchase_receipts_on_store_id_and_status"
    t.index ["supplier_id"], name: "index_purchase_receipts_on_supplier_id"
    t.check_constraint "freight_cents >= 0 AND handling_cents >= 0", name: "purchase_receipts_freight_handling_nonnegative"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'posted'::character varying::text, 'reversed'::character varying::text])", name: "purchase_receipts_status_valid"
    t.check_constraint "supplier_tax_cents >= 0 AND miscellaneous_charges_cents >= 0", name: "purchase_receipts_tax_misc_nonnegative"
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
    t.integer "register_number", null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "register_number"], name: "index_registers_on_store_id_and_register_number", unique: true
    t.check_constraint "receipt_sequence >= 0", name: "registers_receipt_sequence_nonnegative"
    t.check_constraint "register_number > 0", name: "registers_register_number_positive"
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

  create_table "store_document_sequences", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.string "document_kind", null: false
    t.integer "next_value", default: 1, null: false
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "document_kind"], name: "index_store_document_sequences_on_store_and_kind", unique: true
    t.check_constraint "document_kind::text = ANY (ARRAY['customer_request'::character varying::text, 'order'::character varying::text, 'purchase_order'::character varying::text, 'purchase_receipt'::character varying::text])", name: "store_document_sequences_kind_valid"
    t.check_constraint "next_value > 0", name: "store_document_sequences_next_value_positive"
  end

  create_table "store_supplier_source_preferences", id: :uuid, default: nil, force: :cascade do |t|
    t.timestamptz "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "product_variant_id", null: false
    t.uuid "store_id", null: false
    t.uuid "supplier_variant_source_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["store_id", "product_variant_id"], name: "index_store_supplier_source_prefs_on_store_and_variant", unique: true
    t.index ["supplier_variant_source_id"], name: "idx_on_supplier_variant_source_id_4043195088"
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

  create_table "stored_value_accounts", id: :uuid, default: nil, force: :cascade do |t|
    t.string "account_type", null: false
    t.bigint "balance_cents", default: 0, null: false
    t.timestamptz "closed_at"
    t.timestamptz "created_at", null: false
    t.string "currency_code", limit: 3, null: false
    t.uuid "customer_id"
    t.integer "lock_version", default: 0, null: false
    t.timestamptz "opened_at", null: false
    t.string "status", default: "active", null: false
    t.timestamptz "updated_at", null: false
    t.index ["customer_id", "account_type"], name: "index_stored_value_accounts_one_open_per_customer_type", unique: true, where: "((customer_id IS NOT NULL) AND ((status)::text <> 'closed'::text))"
    t.index ["customer_id"], name: "index_stored_value_accounts_on_customer_id"
    t.check_constraint "(account_type::text = ANY (ARRAY['store_credit'::character varying, 'trade_credit'::character varying]::text[])) AND customer_id IS NOT NULL OR account_type::text = 'gift_card'::text AND customer_id IS NULL", name: "stored_value_accounts_customer_matches_type"
    t.check_constraint "account_type::text = ANY (ARRAY['store_credit'::character varying, 'trade_credit'::character varying, 'gift_card'::character varying]::text[])", name: "stored_value_accounts_type_valid"
    t.check_constraint "balance_cents >= 0", name: "stored_value_accounts_balance_nonnegative"
    t.check_constraint "char_length(currency_code::text) = 3", name: "stored_value_accounts_currency_length"
    t.check_constraint "status::text <> 'closed'::text AND closed_at IS NULL OR status::text = 'closed'::text AND closed_at IS NOT NULL AND balance_cents = 0", name: "stored_value_accounts_closed_consistency"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying, 'closed'::character varying]::text[])", name: "stored_value_accounts_status_valid"
  end

  create_table "stored_value_adjustment_reasons", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "allowed_account_types", default: [], null: false, array: true
    t.string "allowed_direction", null: false
    t.boolean "approval_required", default: false, null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.boolean "notes_required", default: false, null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_stored_value_adjustment_reasons_on_code", unique: true
    t.check_constraint "allowed_direction::text = ANY (ARRAY['credit'::character varying, 'debit'::character varying, 'either'::character varying]::text[])", name: "stored_value_adjustment_reasons_direction_valid"
  end

  create_table "stored_value_adjustments", id: :uuid, default: nil, force: :cascade do |t|
    t.string "adjustment_direction", null: false
    t.bigint "amount_cents", null: false
    t.uuid "approved_by_id"
    t.timestamptz "created_at", null: false
    t.text "customer_explanation"
    t.uuid "idempotency_operation_id", null: false
    t.text "internal_notes"
    t.uuid "performed_by_id", null: false
    t.timestamptz "posted_at", null: false
    t.string "reason_code", null: false
    t.uuid "reason_id", null: false
    t.string "reason_name_snapshot", null: false
    t.uuid "reversal_of_id"
    t.uuid "store_id", null: false
    t.uuid "stored_value_account_id", null: false
    t.uuid "stored_value_operation_id"
    t.timestamptz "updated_at", null: false
    t.index ["idempotency_operation_id"], name: "index_stored_value_adjustments_on_idempotency_operation_id"
    t.index ["reversal_of_id"], name: "index_stored_value_adjustments_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["stored_value_account_id"], name: "index_stored_value_adjustments_on_stored_value_account_id"
    t.index ["stored_value_operation_id"], name: "index_stored_value_adjustments_on_stored_value_operation_id", unique: true, where: "(stored_value_operation_id IS NOT NULL)"
    t.check_constraint "adjustment_direction::text = ANY (ARRAY['credit'::character varying, 'debit'::character varying]::text[])", name: "stored_value_adjustments_direction_valid"
    t.check_constraint "amount_cents > 0", name: "stored_value_adjustments_amount_positive"
    t.check_constraint "approved_by_id IS NULL OR approved_by_id <> performed_by_id", name: "stored_value_adjustments_approver_differs"
  end

  create_table "stored_value_entries", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "balance_after_cents", null: false
    t.timestamptz "created_at", null: false
    t.integer "entry_sequence", null: false
    t.uuid "reversal_of_id"
    t.uuid "stored_value_account_id", null: false
    t.uuid "stored_value_operation_id", null: false
    t.index ["reversal_of_id"], name: "index_stored_value_entries_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["stored_value_account_id"], name: "index_stored_value_entries_on_stored_value_account_id"
    t.index ["stored_value_operation_id", "entry_sequence"], name: "index_stored_value_entries_on_operation_and_sequence", unique: true
    t.check_constraint "amount_cents <> 0", name: "stored_value_entries_amount_nonzero"
    t.check_constraint "balance_after_cents >= 0", name: "stored_value_entries_balance_after_nonnegative"
    t.check_constraint "entry_sequence >= 0", name: "stored_value_entries_sequence_nonnegative"
  end

  create_table "stored_value_operations", id: :uuid, default: nil, force: :cascade do |t|
    t.date "business_date", null: false
    t.timestamptz "created_at", null: false
    t.uuid "idempotency_operation_id", null: false
    t.text "notes"
    t.timestamptz "occurred_at", null: false
    t.string "operation_type", null: false
    t.uuid "performed_by_id", null: false
    t.uuid "pos_session_id"
    t.string "reason_code"
    t.string "reason_name_snapshot"
    t.uuid "reversal_of_id"
    t.uuid "store_id", null: false
    t.timestamptz "updated_at", null: false
    t.index ["idempotency_operation_id"], name: "index_stored_value_operations_on_idempotency_operation_id", unique: true
    t.index ["performed_by_id"], name: "index_stored_value_operations_on_performed_by_id"
    t.index ["pos_session_id"], name: "index_stored_value_operations_on_pos_session_id"
    t.index ["reversal_of_id"], name: "index_stored_value_operations_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["store_id"], name: "index_stored_value_operations_on_store_id"
    t.check_constraint "operation_type::text = ANY (ARRAY['issue'::character varying, 'activate'::character varying, 'reload'::character varying, 'redeem'::character varying, 'refund'::character varying, 'cash_out'::character varying, 'transfer'::character varying, 'adjust'::character varying, 'reverse'::character varying]::text[])", name: "stored_value_operations_type_valid"
  end

  create_table "stored_value_transfers", id: :uuid, default: nil, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.uuid "approved_by_id"
    t.timestamptz "created_at", null: false
    t.uuid "from_account_id", null: false
    t.uuid "merge_idempotency_operation_id"
    t.text "notes"
    t.uuid "performed_by_id", null: false
    t.timestamptz "posted_at", null: false
    t.string "reason_code"
    t.string "reason_name_snapshot"
    t.uuid "reversal_of_id"
    t.uuid "source_customer_id"
    t.uuid "stored_value_operation_id"
    t.uuid "survivor_customer_id"
    t.uuid "to_account_id", null: false
    t.string "transfer_type", null: false
    t.timestamptz "updated_at", null: false
    t.index ["from_account_id"], name: "index_stored_value_transfers_on_from_account_id"
    t.index ["reversal_of_id"], name: "index_stored_value_transfers_on_reversal_of_id", unique: true, where: "(reversal_of_id IS NOT NULL)"
    t.index ["stored_value_operation_id"], name: "index_stored_value_transfers_on_stored_value_operation_id", unique: true, where: "(stored_value_operation_id IS NOT NULL)"
    t.index ["to_account_id"], name: "index_stored_value_transfers_on_to_account_id"
    t.check_constraint "amount_cents > 0", name: "stored_value_transfers_amount_positive"
    t.check_constraint "approved_by_id IS NULL OR approved_by_id <> performed_by_id", name: "stored_value_transfers_approver_differs"
    t.check_constraint "from_account_id <> to_account_id", name: "stored_value_transfers_accounts_differ"
    t.check_constraint "transfer_type::text = ANY (ARRAY['customer_merge'::character varying, 'administrative'::character varying, 'account_consolidation'::character varying]::text[])", name: "stored_value_transfers_type_valid"
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
    t.string "receipt_footer_mode", default: "inherit", null: false
    t.text "receipt_header"
    t.string "receipt_header_mode", default: "inherit", null: false
    t.string "region_code"
    t.string "san"
    t.integer "store_number", null: false
    t.string "street_address_1"
    t.string "street_address_2"
    t.string "timezone", null: false
    t.timestamptz "updated_at", null: false
    t.index "lower((code)::text)", name: "index_stores_on_lower_code", unique: true
    t.index ["store_number"], name: "index_stores_on_store_number", unique: true
    t.check_constraint "receipt_footer_mode::text <> 'custom'::text OR receipt_footer IS NOT NULL AND length(btrim(receipt_footer)) > 0", name: "stores_receipt_footer_custom_text"
    t.check_constraint "receipt_footer_mode::text = ANY (ARRAY['inherit'::character varying::text, 'custom'::character varying::text, 'none'::character varying::text])", name: "stores_receipt_footer_mode_valid"
    t.check_constraint "receipt_header_mode::text <> 'custom'::text OR receipt_header IS NOT NULL AND length(btrim(receipt_header)) > 0", name: "stores_receipt_header_custom_text"
    t.check_constraint "receipt_header_mode::text = ANY (ARRAY['inherit'::character varying::text, 'custom'::character varying::text, 'none'::character varying::text])", name: "stores_receipt_header_mode_valid"
    t.check_constraint "store_number > 0", name: "stores_store_number_positive"
  end

  create_table "subject_headings", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code"
    t.timestamptz "created_at", null: false
    t.integer "display_order"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.uuid "subject_scheme_id", null: false
    t.uuid "suggested_merchandise_class_id"
    t.timestamptz "updated_at", null: false
    t.index ["id", "subject_scheme_id"], name: "index_subject_headings_id_and_scheme", unique: true
    t.index ["subject_scheme_id", "code"], name: "index_subject_headings_scheme_code", unique: true, where: "(code IS NOT NULL)"
  end

  create_table "subject_schemes", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.timestamptz "created_at", null: false
    t.string "key", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.string "scheme_version"
    t.timestamptz "updated_at", null: false
    t.index ["key"], name: "index_subject_schemes_on_key", unique: true
  end

  create_table "supplier_variant_sources", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.timestamptz "created_at", null: false
    t.integer "discount_basis_points"
    t.integer "expected_unit_cost_cents"
    t.integer "lock_version", default: 0, null: false
    t.boolean "organization_preferred", default: false, null: false
    t.string "pricing_method", null: false
    t.uuid "product_variant_id", null: false
    t.uuid "supplier_id", null: false
    t.string "supplier_item_number"
    t.integer "supplier_list_price_cents"
    t.timestamptz "updated_at", null: false
    t.index ["product_variant_id"], name: "index_supplier_variant_sources_on_product_variant_id"
    t.index ["product_variant_id"], name: "index_supplier_variant_sources_one_org_preferred_active", unique: true, where: "((organization_preferred = true) AND (active = true))"
    t.index ["supplier_id", "supplier_item_number"], name: "index_supplier_variant_sources_on_supplier_and_item_number", unique: true, where: "(supplier_item_number IS NOT NULL)"
    t.index ["supplier_id"], name: "index_supplier_variant_sources_on_supplier_id"
    t.check_constraint "pricing_method::text = ANY (ARRAY['discount_from_list'::character varying::text, 'direct_unit_cost'::character varying::text])", name: "supplier_variant_sources_pricing_method_valid"
  end

  create_table "suppliers", id: :uuid, default: nil, force: :cascade do |t|
    t.string "account_number"
    t.boolean "active", default: true, null: false
    t.string "city"
    t.string "code", null: false
    t.string "contact_name"
    t.string "country_code", limit: 2
    t.timestamptz "created_at", null: false
    t.string "email"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.text "ordering_notes"
    t.string "phone"
    t.string "postal_code"
    t.string "region_code"
    t.string "street_address_1"
    t.string "street_address_2"
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_suppliers_on_code", unique: true
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
    t.bigint "stored_value_adjust_credit_approval_threshold_cents", default: 5000, null: false
    t.timestamptz "updated_at", null: false
    t.index ["singleton_key"], name: "index_system_settings_on_singleton_key", unique: true
    t.check_constraint "default_customer_reservation_expiration_days > 0", name: "system_settings_reservation_days_positive"
    t.check_constraint "default_supplier_cancellation_days >= 0", name: "system_settings_supplier_cancellation_days_nonnegative"
    t.check_constraint "fiscal_year_start_month >= 1 AND fiscal_year_start_month <= 12", name: "system_settings_fiscal_year_start_month_range"
    t.check_constraint "singleton_key = true", name: "system_settings_singleton_key_true"
    t.check_constraint "stored_value_adjust_credit_approval_threshold_cents >= 0", name: "system_settings_sv_adjust_threshold_nonnegative"
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

  create_table "tender_types", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "allows_generic_refund_destination", default: false, null: false
    t.boolean "allows_original_tender_refund", default: false, null: false
    t.boolean "allows_refund", default: false, null: false
    t.boolean "allows_refund_instrument_replacement", default: false, null: false
    t.string "behavioral_category", null: false
    t.string "code", null: false
    t.timestamptz "created_at", null: false
    t.string "external_reference_policy", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.string "stored_value_account_type"
    t.boolean "system_protected", default: false, null: false
    t.timestamptz "updated_at", null: false
    t.index ["code"], name: "index_tender_types_on_code", unique: true
    t.check_constraint "behavioral_category::text = 'stored_value'::text AND (stored_value_account_type::text = ANY (ARRAY['store_credit'::character varying, 'trade_credit'::character varying, 'gift_card'::character varying]::text[])) OR behavioral_category::text <> 'stored_value'::text AND stored_value_account_type IS NULL", name: "tender_types_sv_account_type_matches"
    t.check_constraint "behavioral_category::text = ANY (ARRAY['cash'::character varying, 'card'::character varying, 'check'::character varying, 'other'::character varying, 'stored_value'::character varying]::text[])", name: "tender_types_category_valid"
    t.check_constraint "code::text <> 'cash'::text OR allows_refund = true", name: "tender_types_cash_allows_refund"
    t.check_constraint "external_reference_policy::text = ANY (ARRAY['omitted'::character varying::text, 'optional'::character varying::text, 'required'::character varying::text])", name: "tender_types_reference_policy_valid"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_events", "registers"
  add_foreign_key "audit_events", "stores"
  add_foreign_key "audit_events", "user_sessions"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "customer_request_allocations", "customer_requests", on_delete: :restrict
  add_foreign_key "customer_request_allocations", "inventory_units", on_delete: :restrict
  add_foreign_key "customer_request_allocations", "pos_transaction_lines", column: "fulfilled_pos_transaction_line_id", on_delete: :restrict
  add_foreign_key "customer_request_allocations", "purchase_receipt_lines", on_delete: :restrict
  add_foreign_key "customer_request_allocations", "users", column: "released_by_id", on_delete: :restrict
  add_foreign_key "customer_requests", "customers", on_delete: :restrict
  add_foreign_key "customer_requests", "product_variants", on_delete: :restrict
  add_foreign_key "customer_requests", "stores", on_delete: :restrict
  add_foreign_key "customer_requests", "users", column: "cancelled_by_id", on_delete: :restrict
  add_foreign_key "customer_requests", "users", column: "location_failed_by_id", on_delete: :restrict
  add_foreign_key "customers", "customers", column: "merged_into_customer_id", on_delete: :restrict
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
  add_foreign_key "gift_card_cash_outs", "gift_card_cash_outs", column: "reversal_of_id"
  add_foreign_key "gift_card_cash_outs", "gift_cards"
  add_foreign_key "gift_card_cash_outs", "pos_sessions"
  add_foreign_key "gift_card_cash_outs", "registers"
  add_foreign_key "gift_card_cash_outs", "stored_value_accounts"
  add_foreign_key "gift_card_cash_outs", "stored_value_operations"
  add_foreign_key "gift_card_cash_outs", "stores"
  add_foreign_key "gift_card_cash_outs", "users", column: "approved_by_id"
  add_foreign_key "gift_card_cash_outs", "users", column: "performed_by_id"
  add_foreign_key "gift_card_cash_outs", "users", column: "physical_cash_confirmed_by_id"
  add_foreign_key "gift_card_replacements", "gift_card_replacements", column: "reversal_of_id"
  add_foreign_key "gift_card_replacements", "gift_cards", column: "original_gift_card_id"
  add_foreign_key "gift_card_replacements", "gift_cards", column: "replacement_gift_card_id"
  add_foreign_key "gift_card_replacements", "stored_value_operations"
  add_foreign_key "gift_card_replacements", "users", column: "approved_by_id"
  add_foreign_key "gift_card_replacements", "users", column: "performed_by_id"
  add_foreign_key "gift_cards", "customers"
  add_foreign_key "gift_cards", "gift_card_programs"
  add_foreign_key "gift_cards", "gift_cards", column: "replaced_by_id"
  add_foreign_key "gift_cards", "stored_value_accounts"
  add_foreign_key "gift_cards", "stores", column: "activated_store_id"
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
  add_foreign_key "merchandise_categories", "merchandise_classes", column: "default_standard_merchandise_class_id"
  add_foreign_key "merchandise_categories", "merchandise_classes", column: "default_used_merchandise_class_id"
  add_foreign_key "merchandise_classes", "departments"
  add_foreign_key "merchandise_classes", "tax_classes", column: "default_tax_class_id"
  add_foreign_key "orders", "customer_requests", on_delete: :restrict
  add_foreign_key "orders", "orders", column: "replaces_order_id", on_delete: :restrict
  add_foreign_key "orders", "product_variants", on_delete: :restrict
  add_foreign_key "orders", "stores", on_delete: :restrict
  add_foreign_key "orders", "suppliers", on_delete: :restrict
  add_foreign_key "orders", "users", column: "cancelled_by_id", on_delete: :restrict
  add_foreign_key "pos_controlled_actions", "gift_card_cash_outs"
  add_foreign_key "pos_controlled_actions", "pos_transaction_lines"
  add_foreign_key "pos_controlled_actions", "pos_transactions"
  add_foreign_key "pos_controlled_actions", "users", column: "approved_by_user_id"
  add_foreign_key "pos_controlled_actions", "users", column: "performed_by_user_id"
  add_foreign_key "pos_gift_card_credential_deliveries", "gift_cards"
  add_foreign_key "pos_gift_card_credential_deliveries", "pos_transactions"
  add_foreign_key "pos_line_tax_components", "pos_transaction_lines"
  add_foreign_key "pos_line_tax_components", "store_taxes"
  add_foreign_key "pos_operations", "pos_transactions"
  add_foreign_key "pos_operations", "registers"
  add_foreign_key "pos_operations", "stores"
  add_foreign_key "pos_reporting_periods", "registers"
  add_foreign_key "pos_reporting_periods", "stores"
  add_foreign_key "pos_reporting_periods", "users", column: "finalized_by_user_id"
  add_foreign_key "pos_sessions", "pos_reporting_periods", column: "reporting_period_id"
  add_foreign_key "pos_sessions", "registers"
  add_foreign_key "pos_sessions", "stores"
  add_foreign_key "pos_sessions", "users", column: "cashier_user_id"
  add_foreign_key "pos_stored_value_issuances", "gift_card_programs"
  add_foreign_key "pos_stored_value_issuances", "gift_cards"
  add_foreign_key "pos_stored_value_issuances", "pos_stored_value_issuances", column: "post_void_source_issuance_id"
  add_foreign_key "pos_stored_value_issuances", "pos_transactions"
  add_foreign_key "pos_stored_value_issuances", "stored_value_operations"
  add_foreign_key "pos_stored_value_tender_details", "gift_card_programs"
  add_foreign_key "pos_stored_value_tender_details", "gift_cards"
  add_foreign_key "pos_stored_value_tender_details", "pos_tenders"
  add_foreign_key "pos_stored_value_tender_details", "stored_value_accounts"
  add_foreign_key "pos_stored_value_tender_details", "stored_value_operations"
  add_foreign_key "pos_tenders", "pos_tenders", column: "post_void_source_tender_id", on_delete: :restrict
  add_foreign_key "pos_tenders", "pos_transactions"
  add_foreign_key "pos_tenders", "tender_types", on_delete: :restrict
  add_foreign_key "pos_transaction_lines", "customer_request_allocations", on_delete: :restrict
  add_foreign_key "pos_transaction_lines", "inventory_units", on_delete: :restrict
  add_foreign_key "pos_transaction_lines", "pos_transaction_lines", column: "original_transaction_line_id", on_delete: :restrict
  add_foreign_key "pos_transaction_lines", "pos_transaction_lines", column: "post_void_source_line_id", on_delete: :restrict
  add_foreign_key "pos_transaction_lines", "pos_transactions"
  add_foreign_key "pos_transaction_lines", "product_variants"
  add_foreign_key "pos_transaction_lines", "tax_classes"
  add_foreign_key "pos_transaction_lines", "tax_classes", column: "default_tax_class_id"
  add_foreign_key "pos_transactions", "customers"
  add_foreign_key "pos_transactions", "pos_reporting_periods", column: "reporting_period_id"
  add_foreign_key "pos_transactions", "pos_sessions"
  add_foreign_key "pos_transactions", "pos_transactions", column: "post_void_of_transaction_id", on_delete: :restrict
  add_foreign_key "pos_transactions", "registers"
  add_foreign_key "pos_transactions", "stores"
  add_foreign_key "pos_transactions", "users", column: "cashier_user_id"
  add_foreign_key "product_contributions", "products"
  add_foreign_key "product_subject_assignments", "products"
  add_foreign_key "product_subject_assignments", "subject_headings"
  add_foreign_key "product_subject_assignments", "subject_headings", column: ["subject_heading_id", "subject_scheme_id"], primary_key: ["id", "subject_scheme_id"], name: "fk_product_subject_assignments_heading_scheme"
  add_foreign_key "product_subject_assignments", "subject_schemes"
  add_foreign_key "product_variants", "merchandise_classes"
  add_foreign_key "product_variants", "merchandise_conditions"
  add_foreign_key "product_variants", "products"
  add_foreign_key "product_variants", "tax_classes", column: "tax_class_override_id"
  add_foreign_key "products", "merchandise_categories"
  add_foreign_key "products", "product_forms"
  add_foreign_key "purchase_order_line_cancellations", "purchase_order_lines", on_delete: :restrict
  add_foreign_key "purchase_order_line_cancellations", "users", column: "recorded_by_id", on_delete: :restrict
  add_foreign_key "purchase_order_line_states", "purchase_order_lines", on_delete: :restrict
  add_foreign_key "purchase_order_lines", "orders", on_delete: :restrict
  add_foreign_key "purchase_order_lines", "product_variants", on_delete: :restrict
  add_foreign_key "purchase_order_lines", "purchase_orders", on_delete: :restrict
  add_foreign_key "purchase_orders", "stores", on_delete: :restrict
  add_foreign_key "purchase_orders", "suppliers", on_delete: :restrict
  add_foreign_key "purchase_orders", "users", column: "generated_by_id", on_delete: :restrict
  add_foreign_key "purchase_orders", "users", column: "sent_by_id", on_delete: :restrict
  add_foreign_key "purchase_receipt_line_corrections", "purchase_receipt_lines", on_delete: :restrict
  add_foreign_key "purchase_receipt_line_corrections", "users", column: "recorded_by_id", on_delete: :restrict
  add_foreign_key "purchase_receipt_lines", "product_variants", on_delete: :restrict
  add_foreign_key "purchase_receipt_lines", "purchase_order_lines", on_delete: :restrict
  add_foreign_key "purchase_receipt_lines", "purchase_receipts", on_delete: :restrict
  add_foreign_key "purchase_receipts", "stores", on_delete: :restrict
  add_foreign_key "purchase_receipts", "suppliers", on_delete: :restrict
  add_foreign_key "purchase_receipts", "users", column: "posted_by_id", on_delete: :restrict
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
  add_foreign_key "store_document_sequences", "stores", on_delete: :restrict
  add_foreign_key "store_supplier_source_preferences", "product_variants", on_delete: :restrict
  add_foreign_key "store_supplier_source_preferences", "stores", on_delete: :restrict
  add_foreign_key "store_supplier_source_preferences", "supplier_variant_sources", on_delete: :restrict
  add_foreign_key "store_tax_rules", "store_taxes"
  add_foreign_key "store_tax_rules", "tax_classes"
  add_foreign_key "store_taxes", "stores"
  add_foreign_key "stored_value_accounts", "customers"
  add_foreign_key "stored_value_adjustments", "idempotency_operations"
  add_foreign_key "stored_value_adjustments", "stored_value_accounts"
  add_foreign_key "stored_value_adjustments", "stored_value_adjustment_reasons", column: "reason_id"
  add_foreign_key "stored_value_adjustments", "stored_value_adjustments", column: "reversal_of_id"
  add_foreign_key "stored_value_adjustments", "stored_value_operations"
  add_foreign_key "stored_value_adjustments", "stores"
  add_foreign_key "stored_value_adjustments", "users", column: "approved_by_id"
  add_foreign_key "stored_value_adjustments", "users", column: "performed_by_id"
  add_foreign_key "stored_value_entries", "stored_value_accounts"
  add_foreign_key "stored_value_entries", "stored_value_entries", column: "reversal_of_id"
  add_foreign_key "stored_value_entries", "stored_value_operations"
  add_foreign_key "stored_value_operations", "idempotency_operations"
  add_foreign_key "stored_value_operations", "pos_sessions"
  add_foreign_key "stored_value_operations", "stored_value_operations", column: "reversal_of_id"
  add_foreign_key "stored_value_operations", "stores"
  add_foreign_key "stored_value_operations", "users", column: "performed_by_id"
  add_foreign_key "stored_value_transfers", "customers", column: "source_customer_id"
  add_foreign_key "stored_value_transfers", "customers", column: "survivor_customer_id"
  add_foreign_key "stored_value_transfers", "idempotency_operations", column: "merge_idempotency_operation_id"
  add_foreign_key "stored_value_transfers", "stored_value_accounts", column: "from_account_id"
  add_foreign_key "stored_value_transfers", "stored_value_accounts", column: "to_account_id"
  add_foreign_key "stored_value_transfers", "stored_value_operations"
  add_foreign_key "stored_value_transfers", "stored_value_transfers", column: "reversal_of_id"
  add_foreign_key "stored_value_transfers", "users", column: "approved_by_id"
  add_foreign_key "stored_value_transfers", "users", column: "performed_by_id"
  add_foreign_key "stores", "users", column: "deactivated_by_id"
  add_foreign_key "subject_headings", "merchandise_classes", column: "suggested_merchandise_class_id"
  add_foreign_key "subject_headings", "subject_schemes"
  add_foreign_key "supplier_variant_sources", "product_variants", on_delete: :restrict
  add_foreign_key "supplier_variant_sources", "suppliers", on_delete: :restrict
  add_foreign_key "user_sessions", "users"
  add_foreign_key "user_sessions", "users", column: "revoked_by_id"
  add_foreign_key "users", "users", column: "deactivated_by_id"
end
