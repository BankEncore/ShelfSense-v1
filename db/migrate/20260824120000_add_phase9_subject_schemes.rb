# frozen_string_literal: true

class AddPhase9SubjectSchemes < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :subject_schemes do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :scheme_version
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :subject_schemes, :key, unique: true

    create_uuid_table :subject_headings do |t|
      t.uuid :subject_scheme_id, null: false
      t.string :code
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :display_order
      t.uuid :suggested_merchandise_class_id
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :subject_headings, [ :subject_scheme_id, :code ],
              unique: true, where: "code IS NOT NULL", name: "index_subject_headings_scheme_code"
    add_foreign_key :subject_headings, :subject_schemes
    add_foreign_key :subject_headings, :merchandise_classes, column: :suggested_merchandise_class_id

    create_uuid_table :product_subject_assignments do |t|
      t.uuid :product_id, null: false
      t.uuid :subject_heading_id, null: false
      t.uuid :subject_scheme_id, null: false
      t.integer :position, null: false, default: 0
      t.boolean :primary, null: false, default: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :product_subject_assignments, [ :product_id, :subject_heading_id ],
              unique: true, name: "index_product_subject_assignments_uniqueness"
    add_index :product_subject_assignments, [ :product_id, :subject_scheme_id ],
              unique: true,
              where: "\"primary\" = TRUE",
              name: "index_product_subject_assignments_primary_per_scheme"
    add_foreign_key :product_subject_assignments, :products
    add_foreign_key :product_subject_assignments, :subject_headings
    add_foreign_key :product_subject_assignments, :subject_schemes

    reversible do |dir|
      dir.up { SubjectSchemes::Catalog.seed! }
    end
  end
end
