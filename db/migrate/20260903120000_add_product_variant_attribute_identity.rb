# frozen_string_literal: true

class AddProductVariantAttributeIdentity < ActiveRecord::Migration[8.1]
  def up
    add_column :product_variants, :option_value_1_normalized, :string
    add_column :product_variants, :option_value_2_normalized, :string

    say_with_time "backfill option value normalization and derived names" do
      ProductVariant.includes(:product, :merchandise_condition).find_each do |variant|
        product = variant.product
        v1 = ProductVariants::NameComposer.trim_display(variant.option_value_1)
        v2 = ProductVariants::NameComposer.trim_display(variant.option_value_2)
        unless product.variant_option_name_1.to_s.strip.present?
          v1 = nil
          v2 = nil
        end
        unless product.variant_option_name_2.to_s.strip.present?
          v2 = nil
        end

        derived = ProductVariants::NameComposer.name(
          variant_type: variant.variant_type,
          condition_name: variant.merchandise_condition&.name,
          option_value_1: v1,
          option_value_2: v2,
          product: product
        )

        variant.update_columns(
          option_value_1: v1,
          option_value_2: v2,
          option_value_1_normalized: ProductVariants::NameComposer.normalize_option_value(v1),
          option_value_2_normalized: ProductVariants::NameComposer.normalize_option_value(v2),
          name: derived,
          updated_at: Time.current
        )
      end
    end

    duplicates = execute(<<~SQL.squish).to_a
      SELECT product_id, variant_type, merchandise_condition_id,
             option_value_1_normalized, option_value_2_normalized, COUNT(*) AS cnt
      FROM product_variants
      GROUP BY product_id, variant_type, merchandise_condition_id,
               option_value_1_normalized, option_value_2_normalized
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      report = duplicates.map { |row|
        "product_id=#{row['product_id']} type=#{row['variant_type']} " \
          "condition=#{row['merchandise_condition_id'].inspect} " \
          "opt1=#{row['option_value_1_normalized'].inspect} " \
          "opt2=#{row['option_value_2_normalized'].inspect} count=#{row['cnt']}"
      }.join("\n")
      raise ActiveRecord::IrreversibleMigration,
            "Cannot add unique variant identity index; resolve duplicates first:\n#{report}"
    end

    execute <<~SQL.squish
      CREATE UNIQUE INDEX index_product_variants_on_logical_identity
      ON product_variants (
        product_id,
        variant_type,
        merchandise_condition_id,
        option_value_1_normalized,
        option_value_2_normalized
      ) NULLS NOT DISTINCT
    SQL

    change_column_default :products, :status, from: "draft", to: "active"
    change_column_default :product_variants, :status, from: "draft", to: "active"
  end

  def down
    change_column_default :products, :status, from: "active", to: "draft"
    change_column_default :product_variants, :status, from: "active", to: "draft"
    execute "DROP INDEX IF EXISTS index_product_variants_on_logical_identity"
    remove_column :product_variants, :option_value_1_normalized
    remove_column :product_variants, :option_value_2_normalized
  end
end
