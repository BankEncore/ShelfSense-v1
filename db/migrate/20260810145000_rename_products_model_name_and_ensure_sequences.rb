# frozen_string_literal: true

class RenameProductsModelNameAndEnsureSequences < ActiveRecord::Migration[8.1]
  def up
    rename_column :products, :model_name, :product_model if column_exists?(:products, :model_name)

    execute <<~SQL.squish
      CREATE SEQUENCE IF NOT EXISTS shelfsense_sku_221_seq
        AS bigint
        MINVALUE 0
        MAXVALUE 999999999
        START WITH 0
        INCREMENT BY 1
        NO CYCLE
    SQL
    execute <<~SQL.squish
      CREATE SEQUENCE IF NOT EXISTS shelfsense_product_222_seq
        AS bigint
        MINVALUE 0
        MAXVALUE 999999999
        START WITH 0
        INCREMENT BY 1
        NO CYCLE
    SQL
  end

  def down
    rename_column :products, :product_model, :model_name if column_exists?(:products, :product_model)
  end
end
