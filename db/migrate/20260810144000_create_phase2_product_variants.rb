# frozen_string_literal: true

class CreatePhase2ProductVariants < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :product_variants do |t|
      t.uuid :product_id, null: false
      t.string :sku, limit: 13, null: false
      t.string :industry_identifier, limit: 13
      t.string :name
      t.string :option_value_1
      t.string :option_value_2
      t.uuid :merchandise_condition_id, null: false
      t.uuid :merchandise_class_id
      t.uuid :department_id
      t.uuid :tax_class_id
      t.bigint :regular_price_cents
      t.string :status, null: false, default: "draft"
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :product_variants, :sku, unique: true
    add_index :product_variants, :industry_identifier, unique: true, where: "industry_identifier IS NOT NULL"
    add_index :product_variants, [ :product_id, :status ]
    add_index :product_variants, :merchandise_class_id
    add_index :product_variants, :merchandise_condition_id
    add_index :product_variants, :department_id
    add_index :product_variants, :tax_class_id
    add_foreign_key :product_variants, :products
    add_foreign_key :product_variants, :merchandise_conditions
    add_foreign_key :product_variants, :merchandise_classes
    add_foreign_key :product_variants, :departments
    add_foreign_key :product_variants, :tax_classes
    add_check_constraint :product_variants, "status IN ('draft', 'active', 'discontinued')", name: "product_variants_status_valid"
    add_check_constraint :product_variants, "sku ~ '^[0-9]{13}$'", name: "product_variants_sku_shape"
    add_check_constraint :product_variants,
                         "industry_identifier IS NULL OR industry_identifier ~ '^[0-9]{13}$'",
                         name: "product_variants_industry_identifier_shape"
    add_check_constraint :product_variants,
                         "regular_price_cents IS NULL OR regular_price_cents >= 0",
                         name: "product_variants_regular_price_nonnegative"

    add_column :identifier_registry, :product_variant_id, :uuid
    add_foreign_key :identifier_registry, :product_variants, column: :product_variant_id, on_delete: :nullify
    add_index :identifier_registry, :product_variant_id, unique: true,
              where: "identifier_kind = 'variant_sku'",
              name: "index_identifier_registry_variant_sku"
    add_index :identifier_registry, :product_variant_id, unique: true,
              where: "identifier_kind = 'variant_industry' AND retired_at IS NULL",
              name: "index_identifier_registry_active_variant_industry"

    remove_check_constraint :identifier_registry, name: "identifier_registry_active_requires_owner"
    add_check_constraint :identifier_registry,
                         "(retired_at IS NOT NULL) OR ((product_id IS NOT NULL)::int + (product_variant_id IS NOT NULL)::int = 1)",
                         name: "identifier_registry_active_requires_one_owner"
  end
end
