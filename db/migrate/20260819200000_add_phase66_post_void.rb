# frozen_string_literal: true

class AddPhase66PostVoid < ActiveRecord::Migration[8.1]
  def up
    add_reference :pos_transactions, :post_void_of_transaction, type: :uuid, index: false,
                  foreign_key: { to_table: :pos_transactions, on_delete: :restrict }
    add_index :pos_transactions, :post_void_of_transaction_id,
              unique: true,
              where: "post_void_of_transaction_id IS NOT NULL",
              name: "index_pos_transactions_one_post_void_per_source"
    add_check_constraint :pos_transactions,
                         "post_void_of_transaction_id IS NULL OR post_void_of_transaction_id <> id",
                         name: "pos_transactions_post_void_not_self"

    add_reference :pos_transaction_lines, :post_void_source_line, type: :uuid, index: false,
                  foreign_key: { to_table: :pos_transaction_lines, on_delete: :restrict }
    add_index :pos_transaction_lines, :post_void_source_line_id,
              unique: true,
              where: "post_void_source_line_id IS NOT NULL",
              name: "index_pos_transaction_lines_one_post_void_source"
    add_check_constraint :pos_transaction_lines,
                         "post_void_source_line_id IS NULL OR post_void_source_line_id <> id",
                         name: "pos_transaction_lines_post_void_source_not_self"
    add_check_constraint :pos_transaction_lines,
                         "original_transaction_line_id IS NULL OR post_void_source_line_id IS NULL",
                         name: "pos_transaction_lines_lineage_exclusive"

    remove_check_constraint :pos_transaction_lines, name: "pos_transaction_lines_return_reason_rules"
    add_check_constraint :pos_transaction_lines,
                         <<~SQL.squish,
                           (direction = 'sale'
                             AND original_transaction_line_id IS NULL
                             AND return_reason_code IS NULL
                             AND return_reason_name_snapshot IS NULL
                             AND return_reason_note IS NULL)
                           OR
                           (direction = 'return'
                             AND post_void_source_line_id IS NOT NULL
                             AND original_transaction_line_id IS NULL
                             AND return_reason_code IS NULL
                             AND return_reason_name_snapshot IS NULL
                             AND return_reason_note IS NULL)
                           OR
                           (direction = 'return'
                             AND post_void_source_line_id IS NULL
                             AND return_reason_code IS NOT NULL
                             AND return_reason_name_snapshot IS NOT NULL
                             AND return_reason_code IN ('changed_mind', 'defective', 'wrong_item', 'duplicate_purchase', 'other')
                             AND (
                               (return_reason_code <> 'other' AND return_reason_note IS NULL)
                               OR (return_reason_code = 'other' AND return_reason_note IS NOT NULL AND char_length(return_reason_note) BETWEEN 1 AND 200)
                             ))
                         SQL
                         name: "pos_transaction_lines_return_reason_rules"

    add_reference :pos_tenders, :post_void_source_tender, type: :uuid, index: false,
                  foreign_key: { to_table: :pos_tenders, on_delete: :restrict }
    add_index :pos_tenders, :post_void_source_tender_id,
              unique: true,
              where: "post_void_source_tender_id IS NOT NULL",
              name: "index_pos_tenders_one_post_void_source"
    add_check_constraint :pos_tenders,
                         "post_void_source_tender_id IS NULL OR post_void_source_tender_id <> id",
                         name: "pos_tenders_post_void_source_not_self"

    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_line_present"
    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         "action_type IN ('price_override', 'line_discount', 'tax_class_override', 'unlinked_return', 'post_void')",
                         name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         <<~SQL.squish,
                           (action_type = 'post_void' AND pos_transaction_line_id IS NULL)
                           OR
                           (action_type <> 'post_void' AND pos_transaction_line_id IS NOT NULL)
                         SQL
                         name: "pos_controlled_actions_line_scope"
    add_index :pos_controlled_actions, %i[pos_transaction_id action_type],
              unique: true,
              where: "action_type = 'post_void'",
              name: "index_pos_controlled_actions_one_post_void"

    add_column :pos_reporting_periods, :finalized_post_void_transaction_count, :integer
    add_column :pos_reporting_periods, :finalized_post_void_merchandise_cents, :bigint
    add_column :pos_reporting_periods, :finalized_post_void_discount_cents, :bigint
    add_column :pos_reporting_periods, :finalized_post_void_tax_cents, :bigint
    add_column :pos_reporting_periods, :finalized_post_void_net_cents, :bigint
    add_check_constraint :pos_reporting_periods,
                         "finalized_post_void_transaction_count IS NULL OR finalized_post_void_transaction_count >= 0",
                         name: "pos_reporting_periods_finalized_post_void_count_nonnegative"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "cannot restore prior return-reason and controlled-action CHECKs while post-void rows may exist"
  end
end
