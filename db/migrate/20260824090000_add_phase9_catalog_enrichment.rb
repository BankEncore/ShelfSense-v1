# frozen_string_literal: true

class AddPhase9CatalogEnrichment < ActiveRecord::Migration[8.1]
  def up
    create_uuid_table :publishers do |t|
      t.string :name, null: false
      t.string :name_normalized, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :publishers, :name_normalized, unique: true

    create_uuid_table :contributors do |t|
      t.string :display_name, null: false
      t.string :name_normalized, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :contributors, :name_normalized, unique: true

    create_uuid_table :product_contributions do |t|
      t.uuid :product_id, null: false
      t.uuid :contributor_id, null: false
      t.string :role, null: false
      t.integer :position, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :product_contributions, [ :product_id, :contributor_id, :role ],
              unique: true, name: "index_product_contributions_uniqueness"
    add_index :product_contributions, :contributor_id
    add_foreign_key :product_contributions, :products
    add_foreign_key :product_contributions, :contributors
    add_check_constraint :product_contributions,
                         "role IN ('author', 'illustrator', 'editor', 'translator', 'other')",
                         name: "product_contributions_role_valid"

    add_column :products, :publisher_id, :uuid
    add_column :products, :imprint, :string
    add_column :products, :edition, :string
    add_column :products, :binding, :string
    add_column :products, :language_code, :string
    add_column :products, :page_count, :integer
    add_column :products, :series_name, :string
    add_column :products, :series_position, :string
    add_column :products, :cover_image_url, :string
    add_column :products, :publication_year, :integer
    add_column :products, :bibliographic_provider, :string
    add_column :products, :bibliographic_provider_key, :string
    add_column :products, :bibliographic_fetched_at, :timestamptz
    add_column :products, :bibliographic_applied_at, :timestamptz
    add_column :products, :bibliographic_curated_fields, :string, array: true, null: false, default: []

    add_index :products, :publisher_id
    add_index :products, :bibliographic_provider_key
    add_foreign_key :products, :publishers
    add_check_constraint :products, "page_count IS NULL OR page_count > 0", name: "products_page_count_positive"
    add_check_constraint :products,
                         "publication_year IS NULL OR (publication_year >= 1400 AND publication_year <= 2100)",
                         name: "products_publication_year_range"

    create_uuid_table :bibliographic_lookup_cache do |t|
      t.string :lookup_key, null: false
      t.string :provider, null: false
      t.jsonb :payload, null: false
      t.timestamptz :fetched_at, null: false
      t.timestamptz :expires_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :bibliographic_lookup_cache, :lookup_key, unique: true
  end

  def down
    drop_table :bibliographic_lookup_cache
    remove_check_constraint :products, name: "products_publication_year_range"
    remove_check_constraint :products, name: "products_page_count_positive"
    remove_foreign_key :products, :publishers
    remove_index :products, :bibliographic_provider_key
    remove_index :products, :publisher_id
    remove_column :products, :bibliographic_curated_fields
    remove_column :products, :bibliographic_applied_at
    remove_column :products, :bibliographic_fetched_at
    remove_column :products, :bibliographic_provider_key
    remove_column :products, :bibliographic_provider
    remove_column :products, :publication_year
    remove_column :products, :cover_image_url
    remove_column :products, :series_position
    remove_column :products, :series_name
    remove_column :products, :page_count
    remove_column :products, :language_code
    remove_column :products, :binding
    remove_column :products, :edition
    remove_column :products, :imprint
    remove_column :products, :publisher_id
    drop_table :product_contributions
    drop_table :contributors
    drop_table :publishers
  end
end
