# frozen_string_literal: true

class CreatePhase2Departments < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :departments do |t|
      t.string :code, null: false
      t.string :department_number
      t.string :name, null: false
      t.text :description
      t.uuid :default_tax_class_id, null: false
      t.integer :default_target_margin_bps
      t.uuid :inventory_asset_gl_account_id
      t.uuid :cost_of_goods_sold_gl_account_id
      t.uuid :sales_revenue_gl_account_id
      t.uuid :sales_returns_gl_account_id
      t.uuid :receiving_clearing_gl_account_id
      t.uuid :freight_in_gl_account_id
      t.uuid :inventory_shrinkage_gl_account_id
      t.uuid :inventory_adjustment_gain_gl_account_id
      t.uuid :inventory_adjustment_loss_gl_account_id
      t.uuid :inventory_write_down_gl_account_id
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :departments, :code, unique: true
    add_index :departments, :department_number, unique: true, where: "department_number IS NOT NULL"
    add_foreign_key :departments, :tax_classes, column: :default_tax_class_id
    %w[
      inventory_asset_gl_account_id
      cost_of_goods_sold_gl_account_id
      sales_revenue_gl_account_id
      sales_returns_gl_account_id
      receiving_clearing_gl_account_id
      freight_in_gl_account_id
      inventory_shrinkage_gl_account_id
      inventory_adjustment_gain_gl_account_id
      inventory_adjustment_loss_gl_account_id
      inventory_write_down_gl_account_id
    ].each do |column|
      add_foreign_key :departments, :gl_accounts, column: column
      add_index :departments, column
    end
    add_check_constraint :departments,
                         "default_target_margin_bps IS NULL OR (default_target_margin_bps >= 0 AND default_target_margin_bps < 10000)",
                         name: "departments_margin_bps_range"
  end
end
