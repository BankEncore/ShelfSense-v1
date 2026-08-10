# frozen_string_literal: true

class CreatePhase2ProductsAndRegistry < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      CREATE SEQUENCE shelfsense_sku_221_seq
        AS bigint
        MINVALUE 0
        MAXVALUE 999999999
        START WITH 0
        INCREMENT BY 1
        NO CYCLE
    SQL
    execute <<~SQL.squish
      CREATE SEQUENCE shelfsense_product_222_seq
        AS bigint
        MINVALUE 0
        MAXVALUE 999999999
        START WITH 0
        INCREMENT BY 1
        NO CYCLE
    SQL

    create_uuid_table :products do |t|
      t.string :primary_identifier, limit: 13, null: false
      t.string :name, null: false
      t.string :subtitle
      t.text :description
      t.string :brand_name
      t.string :product_model
      t.uuid :merchandise_category_id
      t.bigint :list_price_cents
      t.date :release_date
      t.string :status, null: false, default: "draft"
      t.string :variant_option_name_1
      t.string :variant_option_name_2
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :products, :primary_identifier, unique: true
    add_index :products, :merchandise_category_id
    add_index :products, [ :status, :name ]
    add_foreign_key :products, :merchandise_categories
    add_check_constraint :products, "status IN ('draft', 'active', 'discontinued')", name: "products_status_valid"
    add_check_constraint :products, "list_price_cents IS NULL OR list_price_cents >= 0", name: "products_list_price_nonnegative"
    add_check_constraint :products, "primary_identifier ~ '^[0-9]{13}$'", name: "products_primary_identifier_shape"

    create_uuid_table :identifier_registry do |t|
      t.string :value, limit: 13, null: false
      t.string :identifier_kind, null: false
      t.uuid :product_id
      t.timestamptz :retired_at
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :identifier_registry, :value, unique: true
    add_index :identifier_registry, :product_id, unique: true,
              where: "identifier_kind = 'product_primary' AND retired_at IS NULL",
              name: "index_identifier_registry_active_product_primary"
    add_foreign_key :identifier_registry, :products, on_delete: :nullify
    add_check_constraint :identifier_registry,
                         "identifier_kind IN ('product_primary', 'variant_sku', 'variant_industry')",
                         name: "identifier_registry_kind_valid"
    add_check_constraint :identifier_registry,
                         "value ~ '^[0-9]{13}$'",
                         name: "identifier_registry_value_shape"
    add_check_constraint :identifier_registry,
                         "(retired_at IS NOT NULL) OR (product_id IS NOT NULL)",
                         name: "identifier_registry_active_requires_owner"
    add_check_constraint :identifier_registry,
                         "identifier_kind <> 'product_primary' OR product_id IS NOT NULL OR retired_at IS NOT NULL",
                         name: "identifier_registry_product_primary_owner"
  end

  def down
    drop_table :identifier_registry
    drop_table :products
    execute "DROP SEQUENCE IF EXISTS shelfsense_product_222_seq"
    execute "DROP SEQUENCE IF EXISTS shelfsense_sku_221_seq"
  end
end
