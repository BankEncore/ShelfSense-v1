# frozen_string_literal: true

class CreatePhase2FinancialClassifications < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :gl_accounts do |t|
      t.string :account_number, null: false
      t.string :name, null: false
      t.text :description
      t.string :account_type, null: false
      t.string :account_category, null: false
      t.uuid :parent_id
      t.boolean :posting_allowed, null: false, default: true
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :gl_accounts, :account_number, unique: true
    add_index :gl_accounts, :parent_id
    add_index :gl_accounts, [ :active, :account_number ]
    add_foreign_key :gl_accounts, :gl_accounts, column: :parent_id
    add_check_constraint :gl_accounts, "parent_id IS NULL OR parent_id <> id", name: "gl_accounts_parent_not_self"
    add_check_constraint :gl_accounts,
                         "account_type IN ('asset', 'liability', 'equity', 'revenue', 'expense')",
                         name: "gl_accounts_account_type_valid"

    create_uuid_table :tax_classes do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :tax_classes, :code, unique: true
  end
end
