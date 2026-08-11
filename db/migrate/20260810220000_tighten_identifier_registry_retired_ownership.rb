# frozen_string_literal: true

class TightenIdentifierRegistryRetiredOwnership < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind", if_exists: true

    add_check_constraint :identifier_registry,
                         <<~SQL.squish,
                           ((product_id IS NOT NULL)::int + (product_variant_id IS NOT NULL)::int) <= 1
                           AND (
                             retired_at IS NOT NULL
                             OR (
                               identifier_kind = 'product_primary'
                               AND product_id IS NOT NULL
                               AND product_variant_id IS NULL
                             )
                             OR (
                               identifier_kind IN ('variant_sku', 'variant_industry')
                               AND product_variant_id IS NOT NULL
                               AND product_id IS NULL
                             )
                           )
                         SQL
                         name: "identifier_registry_owner_matches_kind"
  end

  def down
    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind"

    add_check_constraint :identifier_registry,
                         <<~SQL.squish,
                           retired_at IS NOT NULL
                           OR (
                             identifier_kind = 'product_primary'
                             AND product_id IS NOT NULL
                             AND product_variant_id IS NULL
                           )
                           OR (
                             identifier_kind IN ('variant_sku', 'variant_industry')
                             AND product_variant_id IS NOT NULL
                             AND product_id IS NULL
                           )
                         SQL
                         name: "identifier_registry_owner_matches_kind"
  end
end
