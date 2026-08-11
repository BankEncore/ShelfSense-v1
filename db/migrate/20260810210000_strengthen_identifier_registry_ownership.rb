# frozen_string_literal: true

class StrengthenIdentifierRegistryOwnership < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :identifier_registry, name: "identifier_registry_active_requires_one_owner", if_exists: true
    remove_check_constraint :identifier_registry, name: "identifier_registry_product_primary_owner", if_exists: true

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

  def down
    remove_check_constraint :identifier_registry, name: "identifier_registry_owner_matches_kind"

    add_check_constraint :identifier_registry,
                         "(retired_at IS NOT NULL) OR ((product_id IS NOT NULL)::int + (product_variant_id IS NOT NULL)::int = 1)",
                         name: "identifier_registry_active_requires_one_owner"
    add_check_constraint :identifier_registry,
                         "identifier_kind <> 'product_primary' OR product_id IS NOT NULL OR retired_at IS NOT NULL",
                         name: "identifier_registry_product_primary_owner"
  end
end
