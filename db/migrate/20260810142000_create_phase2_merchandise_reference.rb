# frozen_string_literal: true

class CreatePhase2MerchandiseReference < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :merchandise_classes do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :inventory_tracking_mode, null: false
      t.string :pricing_method, null: false
      t.uuid :default_standard_department_id
      t.uuid :default_used_department_id
      t.boolean :used_merchandise_allowed, null: false, default: false
      t.boolean :buyback_allowed, null: false, default: false
      t.boolean :default_returnable, null: false, default: true
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :merchandise_classes, :code, unique: true
    add_foreign_key :merchandise_classes, :departments, column: :default_standard_department_id
    add_foreign_key :merchandise_classes, :departments, column: :default_used_department_id
    add_check_constraint :merchandise_classes,
                         "inventory_tracking_mode IN ('quantity', 'individual', 'non_inventory')",
                         name: "merchandise_classes_tracking_mode_valid"
    add_check_constraint :merchandise_classes,
                         "pricing_method IN ('fixed', 'list_price', 'cost_based', 'open_price')",
                         name: "merchandise_classes_pricing_method_valid"

    create_uuid_table :merchandise_categories do |t|
      t.string :code
      t.string :name, null: false
      t.text :description
      t.uuid :parent_id
      t.uuid :default_merchandise_class_id
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :merchandise_categories, :code, unique: true, where: "code IS NOT NULL"
    add_index :merchandise_categories, "lower(name)", unique: true, where: "parent_id IS NULL", name: "index_merchandise_categories_root_name"
    add_index :merchandise_categories, "parent_id, lower(name)", unique: true, where: "parent_id IS NOT NULL", name: "index_merchandise_categories_sibling_name"
    add_foreign_key :merchandise_categories, :merchandise_categories, column: :parent_id
    add_foreign_key :merchandise_categories, :merchandise_classes, column: :default_merchandise_class_id
    add_check_constraint :merchandise_categories, "parent_id IS NULL OR parent_id <> id", name: "merchandise_categories_parent_not_self"

    create_uuid_table :merchandise_conditions do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.string :department_basis, null: false
      t.integer :price_adjustment_bps, null: false, default: 10_000
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :merchandise_conditions, :code, unique: true
    add_check_constraint :merchandise_conditions,
                         "department_basis IN ('standard', 'used')",
                         name: "merchandise_conditions_department_basis_valid"
    add_check_constraint :merchandise_conditions,
                         "price_adjustment_bps >= 0",
                         name: "merchandise_conditions_price_adjustment_nonnegative"
  end
end
