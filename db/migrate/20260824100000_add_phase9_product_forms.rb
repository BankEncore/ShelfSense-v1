# frozen_string_literal: true

class AddPhase9ProductForms < ActiveRecord::Migration[8.1]
  def up
    create_uuid_table :product_forms do |t|
      t.string :code, null: false, limit: 2
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :product_forms, :code, unique: true
    add_check_constraint :product_forms, "code ~ '^[A-Z]{2}$'", name: "product_forms_code_format"

    add_column :products, :product_form_id, :uuid
    add_column :products, :binding_legacy, :string
    add_index :products, :product_form_id
    add_foreign_key :products, :product_forms

    ProductForms::Catalog.seed!
    migrate_binding_values

    remove_column :products, :binding
  end

  def down
    add_column :products, :binding, :string
    execute "UPDATE products SET binding = binding_legacy WHERE binding_legacy IS NOT NULL"
    remove_foreign_key :products, :product_forms
    remove_index :products, :product_form_id
    remove_column :products, :binding_legacy
    remove_column :products, :product_form_id
    drop_table :product_forms
  end

  private

  def migrate_binding_values
    report = []
    connection.select_all("SELECT id, binding FROM products WHERE binding IS NOT NULL AND btrim(binding) <> ''").each do |row|
      mapped = ProductForms::BindingMigrator.classify(id: row["id"], binding: row["binding"])
      if mapped.code.present?
        form_id = select_value("SELECT id FROM product_forms WHERE code = #{quote(mapped.code)}")
        if form_id
          execute "UPDATE products SET product_form_id = #{quote(form_id)} WHERE id = #{quote(row['id'])}"
          next
        end
      end
      execute "UPDATE products SET binding_legacy = #{quote(row['binding'])} WHERE id = #{quote(row['id'])}"
      report << "#{row['id']}: #{row['binding']}"
    end
    say "Unmapped binding values (#{report.size}): #{report.join('; ')}" if report.any?
  end
end
