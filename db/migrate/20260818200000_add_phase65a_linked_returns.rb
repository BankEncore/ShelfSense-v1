# frozen_string_literal: true

class AddPhase65aLinkedReturns < ActiveRecord::Migration[8.1]
  def up
    add_column :pos_transactions, :return_subtotal_cents, :bigint, null: false, default: 0
    add_column :pos_transactions, :return_discount_cents, :bigint, null: false, default: 0
    add_column :pos_transactions, :return_tax_cents, :bigint, null: false, default: 0
    add_column :pos_transactions, :return_total_cents, :bigint, null: false, default: 0
    add_column :pos_transactions, :signed_net_cents, :bigint, null: false, default: 0

    execute <<~SQL
      UPDATE pos_transactions
      SET signed_net_cents = total_cents
    SQL

    add_check_constraint :pos_transactions,
                         "return_subtotal_cents >= 0 AND return_discount_cents >= 0 AND return_tax_cents >= 0 AND return_total_cents >= 0",
                         name: "pos_transactions_return_totals_nonnegative"
    add_check_constraint :pos_transactions,
                         "return_total_cents = return_subtotal_cents - return_discount_cents + return_tax_cents",
                         name: "pos_transactions_return_total_matches_components"
    add_check_constraint :pos_transactions,
                         "signed_net_cents = (subtotal_cents - discount_cents + tax_cents) - return_total_cents",
                         name: "pos_transactions_signed_net_matches_components"
    add_check_constraint :pos_transactions,
                         "total_cents = ABS(signed_net_cents)",
                         name: "pos_transactions_total_matches_abs_signed_net"

    add_reference :pos_transaction_lines, :original_transaction_line, type: :uuid, foreign_key: { to_table: :pos_transaction_lines, on_delete: :restrict }
    add_column :pos_transaction_lines, :return_reason_code, :string
    add_column :pos_transaction_lines, :return_reason_name_snapshot, :string
    add_column :pos_transaction_lines, :return_reason_note, :text

    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_direction_valid"
    add_check_constraint :pos_transaction_lines,
                         "direction IN ('sale', 'return')",
                         name: "pos_transaction_lines_direction_valid"
    add_check_constraint :pos_transaction_lines,
                         "original_transaction_line_id IS NULL OR direction = 'return'",
                         name: "pos_transaction_lines_original_requires_return"
    add_check_constraint :pos_transaction_lines,
                         <<~SQL.squish,
                           (direction = 'sale'
                             AND original_transaction_line_id IS NULL
                             AND return_reason_code IS NULL
                             AND return_reason_name_snapshot IS NULL
                             AND return_reason_note IS NULL)
                           OR
                           (direction = 'return'
                             AND return_reason_code IS NOT NULL
                             AND return_reason_name_snapshot IS NOT NULL
                             AND return_reason_code IN ('changed_mind', 'defective', 'wrong_item', 'duplicate_purchase', 'other')
                             AND (
                               (return_reason_code <> 'other' AND return_reason_note IS NULL)
                               OR (return_reason_code = 'other' AND return_reason_note IS NOT NULL AND char_length(return_reason_note) BETWEEN 1 AND 200)
                             ))
                         SQL
                         name: "pos_transaction_lines_return_reason_rules"
    add_index :pos_transaction_lines,
              %i[pos_transaction_id original_transaction_line_id],
              unique: true,
              where: "original_transaction_line_id IS NOT NULL",
              name: "index_pos_transaction_lines_one_linked_original"

    remove_check_constraint :pos_tenders, name: "pos_tenders_direction_valid"
    add_check_constraint :pos_tenders,
                         "direction IN ('payment', 'refund')",
                         name: "pos_tenders_direction_valid"
    remove_check_constraint :pos_tenders, name: "pos_tenders_cash_presented_matches"
    add_check_constraint :pos_tenders,
                         <<~SQL.squish,
                           (behavioral_category = 'cash' AND direction = 'payment'
                             AND amount_presented_cents IS NOT NULL AND change_cents IS NOT NULL
                             AND amount_presented_cents >= 0 AND change_cents >= 0
                             AND amount_presented_cents = amount_cents + change_cents)
                           OR (behavioral_category = 'cash' AND direction = 'refund'
                             AND amount_presented_cents IS NULL AND change_cents IS NULL)
                           OR (behavioral_category IN ('card', 'check', 'other')
                             AND amount_presented_cents IS NULL AND change_cents IS NULL)
                         SQL
                         name: "pos_tenders_cash_presented_matches"
    add_index :pos_tenders,
              :pos_transaction_id,
              unique: true,
              where: "behavioral_category = 'cash' AND direction = 'refund'",
              name: "index_pos_tenders_one_cash_refund"

    add_column :tender_types, :allows_refund, :boolean, null: false, default: false
    execute <<~SQL
      UPDATE tender_types
      SET allows_refund = TRUE
      WHERE code IN ('cash', 'card')
    SQL
    add_check_constraint :tender_types,
                         "code <> 'cash' OR allows_refund = TRUE",
                         name: "tender_types_cash_allows_refund"

    remove_check_constraint :pos_sessions, name: "pos_sessions_closing_expected_nonnegative"
    remove_check_constraint :pos_reporting_periods, name: "pos_reporting_periods_finalized_closing_expected_sum_nonnegativ"

    add_column :pos_reporting_periods, :finalized_return_subtotal_cents, :bigint
    add_column :pos_reporting_periods, :finalized_return_discount_cents, :bigint
    add_column :pos_reporting_periods, :finalized_return_tax_cents, :bigint
    add_column :pos_reporting_periods, :finalized_return_total_cents, :bigint
    add_column :pos_reporting_periods, :finalized_net_cents, :bigint
    add_column :pos_reporting_periods, :finalized_cash_refund_cents, :bigint
    add_column :pos_reporting_periods, :finalized_card_refund_cents, :bigint
    add_column :pos_reporting_periods, :finalized_check_refund_cents, :bigint
    add_column :pos_reporting_periods, :finalized_other_refund_cents, :bigint

    %w[
      finalized_return_subtotal_cents
      finalized_return_discount_cents
      finalized_return_tax_cents
      finalized_return_total_cents
      finalized_cash_refund_cents
      finalized_card_refund_cents
      finalized_check_refund_cents
      finalized_other_refund_cents
    ].each do |column|
      add_check_constraint :pos_reporting_periods,
                           "#{column} IS NULL OR #{column} >= 0",
                           name: "pos_reporting_periods_#{column}_nonnegative"
    end
  end

  def down
    %w[
      finalized_return_subtotal_cents
      finalized_return_discount_cents
      finalized_return_tax_cents
      finalized_return_total_cents
      finalized_cash_refund_cents
      finalized_card_refund_cents
      finalized_check_refund_cents
      finalized_other_refund_cents
    ].each do |column|
      remove_check_constraint :pos_reporting_periods, name: "pos_reporting_periods_#{column}_nonnegative"
    end
    remove_column :pos_reporting_periods, :finalized_other_refund_cents
    remove_column :pos_reporting_periods, :finalized_check_refund_cents
    remove_column :pos_reporting_periods, :finalized_card_refund_cents
    remove_column :pos_reporting_periods, :finalized_cash_refund_cents
    remove_column :pos_reporting_periods, :finalized_net_cents
    remove_column :pos_reporting_periods, :finalized_return_total_cents
    remove_column :pos_reporting_periods, :finalized_return_tax_cents
    remove_column :pos_reporting_periods, :finalized_return_discount_cents
    remove_column :pos_reporting_periods, :finalized_return_subtotal_cents

    add_check_constraint :pos_reporting_periods,
                         "finalized_closing_expected_cash_cents_sum IS NULL OR finalized_closing_expected_cash_cents_sum >= 0",
                         name: "pos_reporting_periods_finalized_closing_expected_sum_nonnegativ"
    add_check_constraint :pos_sessions,
                         "closing_expected_cash_cents IS NULL OR closing_expected_cash_cents >= 0",
                         name: "pos_sessions_closing_expected_nonnegative"

    remove_check_constraint :tender_types, name: "tender_types_cash_allows_refund"
    remove_column :tender_types, :allows_refund

    remove_index :pos_tenders, name: "index_pos_tenders_one_cash_refund"
    remove_check_constraint :pos_tenders, name: "pos_tenders_cash_presented_matches"
    add_check_constraint :pos_tenders,
                         <<~SQL.squish,
                           behavioral_category::text = 'cash'::text AND amount_presented_cents IS NOT NULL AND change_cents IS NOT NULL
                             AND amount_presented_cents >= 0 AND change_cents >= 0
                             AND amount_presented_cents = (amount_cents + change_cents)
                           OR (behavioral_category::text = ANY (ARRAY['card'::character varying, 'check'::character varying, 'other'::character varying]::text[]))
                             AND amount_presented_cents IS NULL AND change_cents IS NULL
                         SQL
                         name: "pos_tenders_cash_presented_matches"
    remove_check_constraint :pos_tenders, name: "pos_tenders_direction_valid"
    add_check_constraint :pos_tenders, "direction = 'payment'", name: "pos_tenders_direction_valid"

    remove_index :pos_transaction_lines, name: "index_pos_transaction_lines_one_linked_original"
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_return_reason_rules"
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_original_requires_return"
    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_direction_valid"
    add_check_constraint :pos_transaction_lines, "direction = 'sale'", name: "pos_transaction_lines_direction_valid"
    remove_column :pos_transaction_lines, :return_reason_note
    remove_column :pos_transaction_lines, :return_reason_name_snapshot
    remove_column :pos_transaction_lines, :return_reason_code
    remove_reference :pos_transaction_lines, :original_transaction_line, foreign_key: { to_table: :pos_transaction_lines }

    remove_check_constraint :pos_transactions, name: "pos_transactions_total_matches_abs_signed_net"
    remove_check_constraint :pos_transactions, name: "pos_transactions_signed_net_matches_components"
    remove_check_constraint :pos_transactions, name: "pos_transactions_return_total_matches_components"
    remove_check_constraint :pos_transactions, name: "pos_transactions_return_totals_nonnegative"
    remove_column :pos_transactions, :signed_net_cents
    remove_column :pos_transactions, :return_total_cents
    remove_column :pos_transactions, :return_tax_cents
    remove_column :pos_transactions, :return_discount_cents
    remove_column :pos_transactions, :return_subtotal_cents
  end
end
