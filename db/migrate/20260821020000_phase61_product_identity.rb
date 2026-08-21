# frozen_string_literal: true

# Adds product-level industry identifiers and lookup codes, and the matching
# `product_industry` registry kind. `products` is not truncated: the new columns are
# nullable, so existing rows satisfy both check constraints.
#
# `down` is destructive: it drops the two columns and deletes every `product_industry`
# registry row, so product-level GTINs and lookup codes are lost. Recovery is a restore
# from backup, or re-entry through the admin product screen and CSV import.
class Phase61ProductIdentity < ActiveRecord::Migration[8.1]
  KINDS = %w[product_primary product_industry variant_sku variant_industry inventory_unit].freeze

  def up
    add_column :products, :industry_identifier, :string, limit: 13
    add_column :products, :lookup_code, :string, limit: 64

    add_index :products, :industry_identifier,
              unique: true,
              where: "industry_identifier IS NOT NULL",
              name: "index_products_on_industry_identifier"
    add_index :products, :lookup_code,
              where: "lookup_code IS NOT NULL",
              name: "index_products_on_lookup_code"

    add_check_constraint :products,
                         "industry_identifier IS NULL OR industry_identifier::text ~ '^[0-9]{13}$'::text",
                         name: "products_industry_identifier_shape"
    add_check_constraint :products,
                         <<~SQL.squish,
                           lookup_code IS NULL OR (
                             lookup_code::text = upper(btrim(lookup_code::text))
                             AND char_length(lookup_code::text) >= 1
                             AND char_length(lookup_code::text) <= 64
                             AND lookup_code::text ~ '^[A-Z0-9._/-]+$'
                           )
                         SQL
                         name: "products_lookup_code_canonical"

    remove_check_constraint :identifier_registry, name: "identifier_registry_kind_valid"
    add_check_constraint :identifier_registry,
                         "identifier_kind::text = ANY (ARRAY[#{kind_array_sql}])",
                         name: "identifier_registry_kind_valid"

    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind"
    add_check_constraint :identifier_registry, owner_matches_kind_sql, name: "identifier_registry_owner_matches_kind"

    add_index :identifier_registry, :product_id,
              unique: true,
              where: "((identifier_kind)::text = 'product_industry'::text) AND (retired_at IS NULL)",
              name: "index_identifier_registry_active_product_industry"
  end

  def down
    remove_index :identifier_registry, name: "index_identifier_registry_active_product_industry"

    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind"
    remove_check_constraint :identifier_registry, name: "identifier_registry_kind_valid"

    execute "DELETE FROM identifier_registry WHERE identifier_kind = 'product_industry'"

    add_check_constraint :identifier_registry,
                         "identifier_kind::text = ANY (ARRAY[#{kind_array_sql(KINDS - %w[product_industry])}])",
                         name: "identifier_registry_kind_valid"
    add_check_constraint :identifier_registry,
                         owner_matches_kind_sql(product_kinds: %w[product_primary]),
                         name: "identifier_registry_owner_matches_kind"

    remove_check_constraint :products, name: "products_lookup_code_canonical"
    remove_check_constraint :products, name: "products_industry_identifier_shape"
    remove_index :products, name: "index_products_on_lookup_code"
    remove_index :products, name: "index_products_on_industry_identifier"
    remove_column :products, :lookup_code
    remove_column :products, :industry_identifier
  end

  private

  def kind_array_sql(kinds = KINDS)
    kinds.map { |kind| "'#{kind}'::character varying::text" }.join(", ")
  end

  def owner_matches_kind_sql(product_kinds: %w[product_primary product_industry])
    product_predicate =
      if product_kinds.one?
        "identifier_kind::text = '#{product_kinds.first}'::text"
      else
        "(identifier_kind::text = ANY (ARRAY[#{kind_array_sql(product_kinds)}]))"
      end

    <<~SQL.squish
      ((product_id IS NOT NULL)::integer + (product_variant_id IS NOT NULL)::integer + (inventory_unit_id IS NOT NULL)::integer) <= 1
      AND (
        retired_at IS NOT NULL
        OR #{product_predicate} AND product_id IS NOT NULL AND product_variant_id IS NULL AND inventory_unit_id IS NULL
        OR (identifier_kind::text = ANY (ARRAY['variant_sku'::character varying::text, 'variant_industry'::character varying::text])) AND product_variant_id IS NOT NULL AND product_id IS NULL AND inventory_unit_id IS NULL
        OR identifier_kind::text = 'inventory_unit'::text AND inventory_unit_id IS NOT NULL AND product_id IS NULL AND product_variant_id IS NULL
      )
    SQL
  end
end
