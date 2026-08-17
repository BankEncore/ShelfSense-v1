# frozen_string_literal: true

class CreateStoreTaxes < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :store_taxes do |t|
      t.uuid :store_id, null: false
      t.string :code, null: false
      t.string :name, null: false
      t.decimal :rate_percent, precision: 6, scale: 3, null: false
      t.boolean :active, null: false, default: true
      t.integer :calculation_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :store_taxes, [ :store_id, :code ], unique: true
    add_check_constraint :store_taxes, "rate_percent >= 0 AND rate_percent <= 100", name: "store_taxes_rate_percent_range"
    add_check_constraint :store_taxes, "calculation_order >= 0", name: "store_taxes_calculation_order_nonnegative"
    add_foreign_key :store_taxes, :stores

    create_uuid_table :store_tax_rules do |t|
      t.uuid :store_tax_id, null: false
      t.uuid :tax_class_id, null: false
      t.boolean :applies
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :store_tax_rules, [ :store_tax_id, :tax_class_id ], unique: true
    add_foreign_key :store_tax_rules, :store_taxes
    add_foreign_key :store_tax_rules, :tax_classes
  end
end
