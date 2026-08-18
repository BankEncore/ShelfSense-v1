# frozen_string_literal: true

class AddDefaultAppliedTaxClass < ActiveRecord::Migration[8.1]
  def up
    add_reference :pos_transaction_lines, :default_tax_class, type: :uuid, foreign_key: { to_table: :tax_classes }
    add_column :pos_transaction_lines, :default_tax_class_code_snapshot, :string
    add_column :pos_transaction_lines, :default_tax_class_name_snapshot, :string
    add_column :pos_transaction_lines, :tax_class_name_snapshot, :string

    execute <<~SQL
      UPDATE pos_transaction_lines AS l
      SET default_tax_class_id = l.tax_class_id,
          default_tax_class_code_snapshot = l.tax_class_code_snapshot,
          default_tax_class_name_snapshot = t.name,
          tax_class_name_snapshot = t.name
      FROM tax_classes AS t
      WHERE t.id = l.tax_class_id
        AND l.default_tax_class_id IS NULL
    SQL
  end

  def down
    remove_column :pos_transaction_lines, :tax_class_name_snapshot
    remove_column :pos_transaction_lines, :default_tax_class_name_snapshot
    remove_column :pos_transaction_lines, :default_tax_class_code_snapshot
    remove_reference :pos_transaction_lines, :default_tax_class, foreign_key: { to_table: :tax_classes }
  end
end
