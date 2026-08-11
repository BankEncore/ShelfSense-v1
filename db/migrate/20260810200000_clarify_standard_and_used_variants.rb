# frozen_string_literal: true

class ClarifyStandardAndUsedVariants < ActiveRecord::Migration[8.1]
  def up
    add_column :merchandise_classes, :inventory_mode, :string
    execute <<~SQL.squish
      UPDATE merchandise_classes
      SET inventory_mode = CASE
        WHEN inventory_tracking_mode = 'non_inventory' THEN 'non_inventory'
        ELSE 'inventory'
      END
    SQL
    change_column_null :merchandise_classes, :inventory_mode, false
    remove_check_constraint :merchandise_classes, name: "merchandise_classes_tracking_mode_valid"
    remove_column :merchandise_classes, :inventory_tracking_mode
    add_check_constraint :merchandise_classes,
                         "inventory_mode IN ('inventory', 'non_inventory')",
                         name: "merchandise_classes_inventory_mode_valid"

    remove_check_constraint :merchandise_conditions, name: "merchandise_conditions_department_basis_valid"
    remove_column :merchandise_conditions, :department_basis

    add_column :product_variants, :variant_type, :string
    execute <<~SQL.squish
      UPDATE product_variants
      SET variant_type = CASE
        WHEN merchandise_condition_id IS NULL THEN 'standard'
        ELSE 'used'
      END
    SQL
    change_column_null :product_variants, :variant_type, false
    change_column_null :product_variants, :merchandise_condition_id, true
    add_check_constraint :product_variants,
                         "variant_type IN ('standard', 'used')",
                         name: "product_variants_variant_type_valid"
    add_check_constraint :product_variants,
                         "(variant_type = 'standard' AND merchandise_condition_id IS NULL) OR (variant_type = 'used' AND merchandise_condition_id IS NOT NULL)",
                         name: "product_variants_condition_matches_type"
    add_index :product_variants, [ :product_id, :variant_type ]
  end

  def down
    remove_index :product_variants, [ :product_id, :variant_type ]
    remove_check_constraint :product_variants, name: "product_variants_condition_matches_type"
    remove_check_constraint :product_variants, name: "product_variants_variant_type_valid"

    execute <<~SQL.squish
      UPDATE product_variants
      SET merchandise_condition_id = (
        SELECT id FROM merchandise_conditions ORDER BY created_at ASC LIMIT 1
      )
      WHERE merchandise_condition_id IS NULL
    SQL
    change_column_null :product_variants, :merchandise_condition_id, false
    remove_column :product_variants, :variant_type

    add_column :merchandise_conditions, :department_basis, :string
    execute "UPDATE merchandise_conditions SET department_basis = 'used'"
    change_column_null :merchandise_conditions, :department_basis, false
    add_check_constraint :merchandise_conditions,
                         "department_basis IN ('standard', 'used')",
                         name: "merchandise_conditions_department_basis_valid"

    add_column :merchandise_classes, :inventory_tracking_mode, :string
    execute <<~SQL.squish
      UPDATE merchandise_classes
      SET inventory_tracking_mode = CASE
        WHEN inventory_mode = 'non_inventory' THEN 'non_inventory'
        ELSE 'quantity'
      END
    SQL
    change_column_null :merchandise_classes, :inventory_tracking_mode, false
    remove_check_constraint :merchandise_classes, name: "merchandise_classes_inventory_mode_valid"
    remove_column :merchandise_classes, :inventory_mode
    add_check_constraint :merchandise_classes,
                         "inventory_tracking_mode IN ('quantity', 'individual', 'non_inventory')",
                         name: "merchandise_classes_tracking_mode_valid"
  end
end
