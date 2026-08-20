# frozen_string_literal: true

class AddReceiptPresentationAndLegalName < ActiveRecord::Migration[8.1]
  MODES = "('inherit', 'custom', 'none')"

  def up
    add_column :stores, :receipt_header_mode, :string, null: false, default: "inherit"
    add_column :stores, :receipt_footer_mode, :string, null: false, default: "inherit"

    execute <<~SQL.squish
      UPDATE stores
      SET receipt_header_mode = CASE
        WHEN receipt_header IS NOT NULL AND length(btrim(receipt_header)) > 0 THEN 'custom'
        ELSE 'inherit'
      END,
      receipt_footer_mode = CASE
        WHEN receipt_footer IS NOT NULL AND length(btrim(receipt_footer)) > 0 THEN 'custom'
        ELSE 'inherit'
      END
    SQL

    add_check_constraint :stores,
                         "receipt_header_mode IN #{MODES}",
                         name: "stores_receipt_header_mode_valid"
    add_check_constraint :stores,
                         "receipt_footer_mode IN #{MODES}",
                         name: "stores_receipt_footer_mode_valid"
    add_check_constraint :stores,
                         "receipt_header_mode <> 'custom' OR (receipt_header IS NOT NULL AND length(btrim(receipt_header)) > 0)",
                         name: "stores_receipt_header_custom_text"
    add_check_constraint :stores,
                         "receipt_footer_mode <> 'custom' OR (receipt_footer IS NOT NULL AND length(btrim(receipt_footer)) > 0)",
                         name: "stores_receipt_footer_custom_text"
  end

  def down
    remove_check_constraint :stores, name: "stores_receipt_footer_custom_text"
    remove_check_constraint :stores, name: "stores_receipt_header_custom_text"
    remove_check_constraint :stores, name: "stores_receipt_footer_mode_valid"
    remove_check_constraint :stores, name: "stores_receipt_header_mode_valid"
    remove_column :stores, :receipt_footer_mode
    remove_column :stores, :receipt_header_mode
  end
end
