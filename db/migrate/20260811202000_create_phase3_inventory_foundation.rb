# frozen_string_literal: true

class CreatePhase3InventoryFoundation < ActiveRecord::Migration[8.1]
  def up
    create_uuid_table :adjustment_reasons do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :direction, null: false
      t.boolean :cost_required_for_increase, null: false, default: true
      t.boolean :notes_required, null: false, default: false
      t.boolean :allows_quantity_tracking, null: false, default: true
      t.boolean :allows_individual_tracking, null: false, default: true
      t.boolean :system_protected, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :adjustment_reasons, :code, unique: true
    add_check_constraint :adjustment_reasons,
                         "direction IN ('increase', 'decrease', 'either')",
                         name: "adjustment_reasons_direction_valid"

    create_uuid_table :inventory_balances do |t|
      t.uuid :store_id, null: false
      t.uuid :product_variant_id, null: false
      t.integer :on_hand_quantity, null: false, default: 0
      t.bigint :inventory_value_cents, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :inventory_balances, %i[store_id product_variant_id], unique: true
    add_foreign_key :inventory_balances, :stores
    add_foreign_key :inventory_balances, :product_variants

    create_uuid_table :inventory_units do |t|
      t.uuid :product_variant_id, null: false
      t.uuid :store_id, null: false
      t.string :unit_identifier, limit: 13, null: false
      t.string :lifecycle_state, null: false, default: "on_hand"
      t.bigint :acquisition_cost_cents, null: false
      t.bigint :carrying_value_cents, null: false
      t.bigint :regular_price_cents
      t.text :notes
      t.timestamptz :removed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :inventory_units, :unit_identifier, unique: true
    add_index :inventory_units, %i[store_id product_variant_id lifecycle_state]
    add_foreign_key :inventory_units, :product_variants
    add_foreign_key :inventory_units, :stores
    add_check_constraint :inventory_units,
                         "lifecycle_state IN ('on_hand', 'removed')",
                         name: "inventory_units_lifecycle_valid"
    add_check_constraint :inventory_units,
                         "acquisition_cost_cents >= 0 AND carrying_value_cents >= 0",
                         name: "inventory_units_costs_nonnegative"
    add_check_constraint :inventory_units,
                         "regular_price_cents IS NULL OR regular_price_cents >= 0",
                         name: "inventory_units_regular_price_nonnegative"
    add_check_constraint :inventory_units,
                         "(lifecycle_state = 'on_hand' AND removed_at IS NULL) OR (lifecycle_state = 'removed' AND removed_at IS NOT NULL)",
                         name: "inventory_units_removal_consistency"
    add_check_constraint :inventory_units,
                         "unit_identifier ~ '^[0-9]{13}$'",
                         name: "inventory_units_identifier_shape"

    create_uuid_table :inventory_adjustments do |t|
      t.uuid :store_id, null: false
      t.uuid :product_variant_id, null: false
      t.uuid :inventory_unit_id
      t.uuid :adjustment_reason_id, null: false
      t.integer :quantity_delta, null: false
      t.bigint :acquisition_unit_cost_cents
      t.text :notes
      t.uuid :created_by_id, null: false
      t.date :business_date, null: false
      t.timestamptz :occurred_at, null: false
      t.timestamptz :posted_at, null: false
      t.uuid :reversal_of_id
      t.timestamptz :reversed_at
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :inventory_adjustments, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :inventory_adjustments, %i[store_id product_variant_id occurred_at]
    add_foreign_key :inventory_adjustments, :stores
    add_foreign_key :inventory_adjustments, :product_variants
    add_foreign_key :inventory_adjustments, :inventory_units
    add_foreign_key :inventory_adjustments, :adjustment_reasons
    add_foreign_key :inventory_adjustments, :users, column: :created_by_id
    add_foreign_key :inventory_adjustments, :inventory_adjustments, column: :reversal_of_id
    add_check_constraint :inventory_adjustments,
                         "quantity_delta <> 0",
                         name: "inventory_adjustments_quantity_nonzero"
    add_check_constraint :inventory_adjustments,
                         "acquisition_unit_cost_cents IS NULL OR acquisition_unit_cost_cents >= 0",
                         name: "inventory_adjustments_cost_nonnegative"

    create_uuid_table :inventory_ledger_entries do |t|
      t.uuid :store_id, null: false
      t.uuid :product_variant_id, null: false
      t.uuid :inventory_unit_id
      t.integer :quantity_delta, null: false
      t.string :entry_type, null: false
      t.string :source_type, null: false
      t.uuid :source_id, null: false
      t.integer :effect_sequence, null: false, default: 0
      t.date :business_date, null: false
      t.timestamptz :occurred_at, null: false
      t.string :actor_type, null: false
      t.uuid :actor_id, null: false
      t.uuid :reversal_of_id
      t.timestamptz :created_at, null: false
    end
    add_index :inventory_ledger_entries, %i[source_type source_id effect_sequence], unique: true,
              name: "index_inventory_ledger_entries_on_source_effect"
    add_index :inventory_ledger_entries, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :inventory_ledger_entries, %i[store_id product_variant_id occurred_at]
    add_foreign_key :inventory_ledger_entries, :stores
    add_foreign_key :inventory_ledger_entries, :product_variants
    add_foreign_key :inventory_ledger_entries, :inventory_units
    add_foreign_key :inventory_ledger_entries, :inventory_ledger_entries, column: :reversal_of_id
    add_check_constraint :inventory_ledger_entries,
                         "quantity_delta <> 0",
                         name: "inventory_ledger_entries_quantity_nonzero"
    add_check_constraint :inventory_ledger_entries,
                         "effect_sequence >= 0",
                         name: "inventory_ledger_entries_effect_sequence_nonnegative"

    create_uuid_table :inventory_valuation_entries do |t|
      t.uuid :store_id, null: false
      t.uuid :product_variant_id, null: false
      t.uuid :inventory_unit_id
      t.integer :quantity_delta, null: false
      t.bigint :value_delta_cents, null: false
      t.bigint :acquisition_unit_cost_cents
      t.string :valuation_method, null: false
      t.string :entry_type, null: false
      t.string :source_type, null: false
      t.uuid :source_id, null: false
      t.integer :effect_sequence, null: false, default: 0
      t.jsonb :calculation_metadata, null: false, default: {}
      t.date :business_date, null: false
      t.timestamptz :occurred_at, null: false
      t.uuid :reversal_of_id
      t.timestamptz :created_at, null: false
    end
    add_index :inventory_valuation_entries, %i[source_type source_id effect_sequence], unique: true,
              name: "index_inventory_valuation_entries_on_source_effect"
    add_index :inventory_valuation_entries, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_foreign_key :inventory_valuation_entries, :stores
    add_foreign_key :inventory_valuation_entries, :product_variants
    add_foreign_key :inventory_valuation_entries, :inventory_units
    add_foreign_key :inventory_valuation_entries, :inventory_valuation_entries, column: :reversal_of_id
    add_check_constraint :inventory_valuation_entries,
                         "effect_sequence >= 0",
                         name: "inventory_valuation_entries_effect_sequence_nonnegative"
    add_check_constraint :inventory_valuation_entries,
                         "valuation_method IN ('moving_average', 'specific_identification')",
                         name: "inventory_valuation_entries_method_valid"

    add_column :identifier_registry, :inventory_unit_id, :uuid
    add_foreign_key :identifier_registry, :inventory_units, column: :inventory_unit_id, on_delete: :nullify
    add_index :identifier_registry, :inventory_unit_id, unique: true,
              where: "identifier_kind = 'inventory_unit'",
              name: "index_identifier_registry_inventory_unit"

    remove_check_constraint :identifier_registry, name: "identifier_registry_kind_valid"
    add_check_constraint :identifier_registry,
                         "identifier_kind IN ('product_primary', 'variant_sku', 'variant_industry', 'inventory_unit')",
                         name: "identifier_registry_kind_valid"

    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind"
    add_check_constraint :identifier_registry,
                         <<~SQL.squish,
                           ((product_id IS NOT NULL)::integer + (product_variant_id IS NOT NULL)::integer + (inventory_unit_id IS NOT NULL)::integer) <= 1
                           AND (
                             retired_at IS NOT NULL
                             OR (
                               identifier_kind = 'product_primary'
                               AND product_id IS NOT NULL AND product_variant_id IS NULL AND inventory_unit_id IS NULL
                             )
                             OR (
                               identifier_kind IN ('variant_sku', 'variant_industry')
                               AND product_variant_id IS NOT NULL AND product_id IS NULL AND inventory_unit_id IS NULL
                             )
                             OR (
                               identifier_kind = 'inventory_unit'
                               AND inventory_unit_id IS NOT NULL AND product_id IS NULL AND product_variant_id IS NULL
                             )
                           )
                         SQL
                         name: "identifier_registry_owner_matches_kind"
  end

  def down
    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind"
    add_check_constraint :identifier_registry,
                         "((product_id IS NOT NULL)::integer + (product_variant_id IS NOT NULL)::integer) <= 1 AND (retired_at IS NOT NULL OR identifier_kind::text = 'product_primary'::text AND product_id IS NOT NULL AND product_variant_id IS NULL OR (identifier_kind::text = ANY (ARRAY['variant_sku'::character varying, 'variant_industry'::character varying]::text[])) AND product_variant_id IS NOT NULL AND product_id IS NULL)",
                         name: "identifier_registry_owner_matches_kind"

    remove_check_constraint :identifier_registry, name: "identifier_registry_kind_valid"
    add_check_constraint :identifier_registry,
                         "identifier_kind::text = ANY (ARRAY['product_primary'::character varying, 'variant_sku'::character varying, 'variant_industry'::character varying]::text[])",
                         name: "identifier_registry_kind_valid"

    remove_foreign_key :identifier_registry, column: :inventory_unit_id
    remove_index :identifier_registry, name: "index_identifier_registry_inventory_unit"
    remove_column :identifier_registry, :inventory_unit_id

    drop_table :inventory_valuation_entries
    drop_table :inventory_ledger_entries
    drop_table :inventory_adjustments
    drop_table :inventory_units
    drop_table :inventory_balances
    drop_table :adjustment_reasons
  end
end
