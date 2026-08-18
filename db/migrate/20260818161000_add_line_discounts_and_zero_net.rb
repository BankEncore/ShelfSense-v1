# frozen_string_literal: true

class AddLineDiscountsAndZeroNet < ActiveRecord::Migration[8.1]
  def up
    add_column :pos_transaction_lines, :manual_discount_basis_points, :integer
    add_column :pos_transaction_lines, :manual_discount_cents, :bigint, null: false, default: 0
    add_column :pos_transaction_lines, :net_merchandise_amount_cents, :bigint

    execute <<~SQL
      UPDATE pos_transaction_lines
      SET net_merchandise_amount_cents = extended_selling_amount_cents - manual_discount_cents
      WHERE net_merchandise_amount_cents IS NULL
    SQL

    change_column_null :pos_transaction_lines, :net_merchandise_amount_cents, false

    add_check_constraint :pos_transaction_lines,
                         "manual_discount_cents >= 0",
                         name: "pos_transaction_lines_discount_nonnegative"
    add_check_constraint :pos_transaction_lines,
                         "net_merchandise_amount_cents = extended_selling_amount_cents - manual_discount_cents",
                         name: "pos_transaction_lines_net_matches_extended_minus_discount"
    add_check_constraint :pos_transaction_lines,
                         "manual_discount_basis_points IS NULL OR (manual_discount_basis_points >= 1 AND manual_discount_basis_points <= 10000)",
                         name: "pos_transaction_lines_discount_bp_range"

    add_column :pos_transactions, :discount_cents, :bigint, null: false, default: 0
    add_column :pos_reporting_periods, :finalized_discount_cents, :bigint
    add_check_constraint :pos_reporting_periods,
                         "finalized_discount_cents IS NULL OR finalized_discount_cents >= 0",
                         name: "pos_reporting_periods_finalized_discount_nonnegative"
  end

  def down
    remove_check_constraint :pos_reporting_periods, name: "pos_reporting_periods_finalized_discount_nonnegative"
    remove_column :pos_reporting_periods, :finalized_discount_cents
    remove_column :pos_transactions, :discount_cents
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_discount_bp_range"
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_net_matches_extended_minus_discount"
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_discount_nonnegative"
    remove_column :pos_transaction_lines, :net_merchandise_amount_cents
    remove_column :pos_transaction_lines, :manual_discount_cents
    remove_column :pos_transaction_lines, :manual_discount_basis_points
  end
end
