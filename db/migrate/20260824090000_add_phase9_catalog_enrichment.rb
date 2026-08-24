# frozen_string_literal: true

class AddPhase9CatalogEnrichment < ActiveRecord::Migration[8.1]
  def up
    create_uuid_table :product_contributions do |t|
      t.uuid :product_id, null: false
      t.string :display_name, null: false
      t.string :role, null: false
      t.integer :position, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :product_contributions, [ :product_id, :display_name, :role ],
              unique: true, name: "index_product_contributions_uniqueness"
    add_foreign_key :product_contributions, :products
    add_check_constraint :product_contributions,
                         "role IN ('author', 'editor', 'illustrator', 'translator', 'photographer', 'narrator', 'other')",
                         name: "product_contributions_role_valid"
    add_check_constraint :product_contributions,
                         "position >= 0",
                         name: "product_contributions_position_nonnegative"

    add_column :products, :imprint, :string
    add_column :products, :binding, :string
    add_column :products, :language_code, :string
    add_column :products, :page_count, :integer
    add_column :products, :series_name, :string
    add_column :products, :series_position, :decimal, precision: 8, scale: 3
    add_column :products, :cover_image_url, :string
    add_column :products, :release_date_approximate, :boolean, null: false, default: false
    add_column :products, :bibliographic_provider, :string
    add_column :products, :bibliographic_provider_key, :string
    add_column :products, :bibliographic_fetched_at, :timestamptz
    add_column :products, :bibliographic_applied_at, :timestamptz
    add_column :products, :bibliographic_field_sources, :jsonb, null: false, default: {}

    add_index :products, :bibliographic_provider_key
    add_check_constraint :products, "page_count IS NULL OR page_count > 0", name: "products_page_count_positive"
    add_check_constraint :products,
                         "series_position IS NULL OR (series_position >= -99999.999 AND series_position <= 99999.999)",
                         name: "products_series_position_range"

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
    remove_check_constraint :products, name: "products_series_position_range"
    remove_check_constraint :products, name: "products_page_count_positive"
    remove_index :products, :bibliographic_provider_key
    remove_column :products, :bibliographic_field_sources
    remove_column :products, :bibliographic_applied_at
    remove_column :products, :bibliographic_fetched_at
    remove_column :products, :bibliographic_provider_key
    remove_column :products, :bibliographic_provider
    remove_column :products, :release_date_approximate
    remove_column :products, :cover_image_url
    remove_column :products, :series_position
    remove_column :products, :series_name
    remove_column :products, :page_count
    remove_column :products, :language_code
    remove_column :products, :binding
    remove_column :products, :imprint
    drop_table :product_contributions
  end
end
