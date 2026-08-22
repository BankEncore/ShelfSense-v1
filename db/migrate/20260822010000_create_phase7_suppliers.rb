# frozen_string_literal: true

class CreatePhase7Suppliers < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :suppliers do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :account_number
      t.string :contact_name
      t.string :email
      t.string :phone
      t.string :street_address_1
      t.string :street_address_2
      t.string :city
      t.string :region_code
      t.string :postal_code
      t.string :country_code, limit: 2
      t.text :ordering_notes
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :suppliers, :code, unique: true

    create_uuid_table :supplier_variant_sources do |t|
      t.uuid :supplier_id, null: false
      t.uuid :product_variant_id, null: false
      t.string :supplier_item_number
      t.string :pricing_method, null: false
      t.integer :supplier_list_price_cents
      t.integer :discount_basis_points
      t.integer :expected_unit_cost_cents
      t.boolean :organization_preferred, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :supplier_variant_sources, :supplier_id
    add_index :supplier_variant_sources, :product_variant_id
    add_index :supplier_variant_sources,
              [ :supplier_id, :supplier_item_number ],
              unique: true,
              where: "supplier_item_number IS NOT NULL",
              name: "index_supplier_variant_sources_on_supplier_and_item_number"
    add_index :supplier_variant_sources,
              :product_variant_id,
              unique: true,
              where: "organization_preferred = TRUE AND active = TRUE",
              name: "index_supplier_variant_sources_one_org_preferred_active"
    add_foreign_key :supplier_variant_sources, :suppliers, on_delete: :restrict
    add_foreign_key :supplier_variant_sources, :product_variants, on_delete: :restrict
    add_check_constraint :supplier_variant_sources,
                         "pricing_method IN ('discount_from_list', 'direct_unit_cost')",
                         name: "supplier_variant_sources_pricing_method_valid"

    create_uuid_table :store_supplier_source_preferences do |t|
      t.uuid :store_id, null: false
      t.uuid :product_variant_id, null: false
      t.uuid :supplier_variant_source_id, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :store_supplier_source_preferences,
              [ :store_id, :product_variant_id ],
              unique: true,
              name: "index_store_supplier_source_prefs_on_store_and_variant"
    add_index :store_supplier_source_preferences, :supplier_variant_source_id
    add_foreign_key :store_supplier_source_preferences, :stores, on_delete: :restrict
    add_foreign_key :store_supplier_source_preferences, :product_variants, on_delete: :restrict
    add_foreign_key :store_supplier_source_preferences, :supplier_variant_sources, on_delete: :restrict
  end
end
