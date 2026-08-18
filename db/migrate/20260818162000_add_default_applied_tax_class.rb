# frozen_string_literal: true

class AddDefaultAppliedTaxClass < ActiveRecord::Migration[8.1]
  def up
    add_reference :pos_transaction_lines, :default_tax_class, type: :uuid, foreign_key: { to_table: :tax_classes }
    add_column :pos_transaction_lines, :default_tax_class_code_snapshot, :string
    add_column :pos_transaction_lines, :default_tax_class_name_snapshot, :string
    add_column :pos_transaction_lines, :tax_class_name_snapshot, :string

    execute <<~SQL
      UPDATE pos_transaction_lines
      SET default_tax_class_id = tax_class_id,
          default_tax_class_code_snapshot = tax_class_code_snapshot
      WHERE default_tax_class_id IS NULL
    SQL

    # Working lines have not completed, so current Tax Class names are acceptable.
    # Completed and cancelled names stay NULL: Tax Class names are mutable and were
    # never snapshotted historically.
    execute <<~SQL
      UPDATE pos_transaction_lines AS l
      SET default_tax_class_name_snapshot = t.name,
          tax_class_name_snapshot = t.name
      FROM tax_classes AS t, pos_transactions AS tx
      WHERE t.id = l.tax_class_id
        AND tx.id = l.pos_transaction_id
        AND tx.status = 'working'
    SQL
  end

  def down
    remove_column :pos_transaction_lines, :tax_class_name_snapshot
    remove_column :pos_transaction_lines, :default_tax_class_name_snapshot
    remove_column :pos_transaction_lines, :default_tax_class_code_snapshot
    remove_reference :pos_transaction_lines, :default_tax_class, foreign_key: { to_table: :tax_classes }
  end
end
