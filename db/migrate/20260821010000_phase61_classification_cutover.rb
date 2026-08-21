# frozen_string_literal: true

class Phase61ClassificationCutover < ActiveRecord::Migration[8.1]
  def up
    # Disposable data: wipe merchandise/inventory/POS rows that depend on the old shape.
    say_with_time "clearing disposable merchandise-related data" do
      execute <<~SQL.squish
        TRUNCATE TABLE
          pos_line_tax_components,
          pos_controlled_actions,
          pos_tenders,
          pos_transaction_lines,
          pos_operations,
          pos_transactions,
          pos_sessions,
          pos_reporting_periods,
          inventory_valuation_entries,
          inventory_ledger_entries,
          inventory_units,
          inventory_balances,
          inventory_adjustments,
          identifier_registry,
          product_variants,
          products,
          merchandise_categories,
          merchandise_classes,
          departments
        RESTART IDENTITY CASCADE
      SQL
    end

    # --- departments: drop tax/margin defaults; require department_number ---
    remove_check_constraint :departments, name: "departments_margin_bps_range"
    remove_foreign_key :departments, column: :default_tax_class_id
    remove_column :departments, :default_tax_class_id, :uuid
    remove_column :departments, :default_target_margin_bps, :integer

    remove_index :departments, :department_number if index_exists?(:departments, :department_number)
    change_column_null :departments, :department_number, false
    add_index :departments, :department_number, unique: true

    # --- merchandise_classes: single department + renamed defaults ---
    add_reference :merchandise_classes, :department, type: :uuid, foreign_key: true, null: true
    add_column :merchandise_classes, :merchandise_class_number, :string
    add_reference :merchandise_classes, :default_tax_class, type: :uuid, foreign_key: { to_table: :tax_classes }, null: true
    add_column :merchandise_classes, :target_margin_bps, :integer

    rename_column :merchandise_classes, :inventory_mode, :default_inventory_mode
    rename_column :merchandise_classes, :pricing_method, :default_pricing_method

    remove_check_constraint :merchandise_classes, name: "merchandise_classes_buyback_implies_used_inventory"
    remove_check_constraint :merchandise_classes, name: "merchandise_classes_inventory_mode_valid"
    remove_check_constraint :merchandise_classes, name: "merchandise_classes_pricing_method_valid"

    add_check_constraint :merchandise_classes,
                         "default_inventory_mode::text = ANY (ARRAY['inventory'::character varying::text, 'non_inventory'::character varying::text])",
                         name: "merchandise_classes_default_inventory_mode_valid"
    add_check_constraint :merchandise_classes,
                         "default_pricing_method::text = ANY (ARRAY['fixed'::character varying::text, 'list_price'::character varying::text, 'cost_based'::character varying::text, 'open_price'::character varying::text])",
                         name: "merchandise_classes_default_pricing_method_valid"
    add_check_constraint :merchandise_classes,
                         "NOT buyback_allowed OR used_merchandise_allowed AND default_inventory_mode::text = 'inventory'::text",
                         name: "merchandise_classes_buyback_implies_used_inventory"
    add_check_constraint :merchandise_classes,
                         "target_margin_bps IS NULL OR (target_margin_bps >= 0 AND target_margin_bps < 10000)",
                         name: "merchandise_classes_margin_bps_range"

    remove_foreign_key :merchandise_classes, column: :default_standard_department_id if foreign_key_exists?(:merchandise_classes, column: :default_standard_department_id)
    remove_foreign_key :merchandise_classes, column: :default_used_department_id if foreign_key_exists?(:merchandise_classes, column: :default_used_department_id)
    remove_column :merchandise_classes, :default_standard_department_id, :uuid
    remove_column :merchandise_classes, :default_used_department_id, :uuid

    change_column_null :merchandise_classes, :department_id, false
    change_column_null :merchandise_classes, :merchandise_class_number, false
    change_column_null :merchandise_classes, :default_tax_class_id, false
    add_index :merchandise_classes,
              [ :department_id, :merchandise_class_number ],
              unique: true,
              name: "index_merchandise_classes_on_department_and_number"

    # --- merchandise_categories: standard/used default classes ---
    add_reference :merchandise_categories, :default_standard_merchandise_class,
                  type: :uuid, foreign_key: { to_table: :merchandise_classes }, null: true
    add_reference :merchandise_categories, :default_used_merchandise_class,
                  type: :uuid, foreign_key: { to_table: :merchandise_classes }, null: true
    remove_foreign_key :merchandise_categories, column: :default_merchandise_class_id if foreign_key_exists?(:merchandise_categories, column: :default_merchandise_class_id)
    remove_column :merchandise_categories, :default_merchandise_class_id, :uuid

    # --- product_variants: persisted ops + tax override ---
    add_column :product_variants, :inventory_mode, :string
    add_column :product_variants, :pricing_method, :string
    add_column :product_variants, :target_margin_bps, :integer
    add_column :product_variants, :supplier_returnable, :boolean
    add_reference :product_variants, :tax_class_override,
                  type: :uuid, foreign_key: { to_table: :tax_classes }, null: true

    add_check_constraint :product_variants,
                         "inventory_mode IS NULL OR inventory_mode::text = ANY (ARRAY['inventory'::character varying::text, 'non_inventory'::character varying::text])",
                         name: "product_variants_inventory_mode_valid"
    add_check_constraint :product_variants,
                         "pricing_method IS NULL OR pricing_method::text = ANY (ARRAY['fixed'::character varying::text, 'list_price'::character varying::text, 'cost_based'::character varying::text, 'open_price'::character varying::text])",
                         name: "product_variants_pricing_method_valid"
    add_check_constraint :product_variants,
                         "target_margin_bps IS NULL OR (target_margin_bps >= 0 AND target_margin_bps < 10000)",
                         name: "product_variants_margin_bps_range"

    remove_foreign_key :product_variants, column: :department_id if foreign_key_exists?(:product_variants, column: :department_id)
    remove_foreign_key :product_variants, column: :tax_class_id if foreign_key_exists?(:product_variants, column: :tax_class_id)
    remove_column :product_variants, :department_id, :uuid
    remove_column :product_variants, :tax_class_id, :uuid
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Phase 6.1 classification cutover is not reversible (disposable data)"
  end
end
