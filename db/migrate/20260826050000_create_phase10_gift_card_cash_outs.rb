# frozen_string_literal: true

class CreatePhase10GiftCardCashOuts < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :gift_card_cash_outs do |t|
      t.uuid :gift_card_id, null: false
      t.uuid :stored_value_account_id, null: false
      t.bigint :amount_cents, null: false
      t.uuid :register_id, null: false
      t.uuid :pos_session_id, null: false
      t.uuid :store_id, null: false
      t.date :business_date, null: false
      t.jsonb :program_policy_snapshot, null: false, default: {}
      t.uuid :performed_by_id, null: false
      t.uuid :approved_by_id
      t.uuid :stored_value_operation_id
      t.uuid :reversal_of_id
      t.boolean :physical_cash_confirmed, null: false, default: false
      t.uuid :physical_cash_confirmed_by_id
      t.timestamptz :posted_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :gift_card_cash_outs, :gift_card_id
    add_index :gift_card_cash_outs, :stored_value_account_id
    add_index :gift_card_cash_outs, :register_id
    add_index :gift_card_cash_outs, :pos_session_id
    add_index :gift_card_cash_outs, :store_id
    add_index :gift_card_cash_outs, :stored_value_operation_id, unique: true,
              where: "stored_value_operation_id IS NOT NULL",
              name: "index_gift_card_cash_outs_on_operation"
    add_index :gift_card_cash_outs, :reversal_of_id, unique: true,
              where: "reversal_of_id IS NOT NULL"
    add_foreign_key :gift_card_cash_outs, :gift_cards
    add_foreign_key :gift_card_cash_outs, :stored_value_accounts
    add_foreign_key :gift_card_cash_outs, :registers
    add_foreign_key :gift_card_cash_outs, :pos_sessions
    add_foreign_key :gift_card_cash_outs, :stores
    add_foreign_key :gift_card_cash_outs, :users, column: :performed_by_id
    add_foreign_key :gift_card_cash_outs, :users, column: :approved_by_id
    add_foreign_key :gift_card_cash_outs, :users, column: :physical_cash_confirmed_by_id
    add_foreign_key :gift_card_cash_outs, :stored_value_operations
    add_foreign_key :gift_card_cash_outs, :gift_card_cash_outs, column: :reversal_of_id
    add_check_constraint :gift_card_cash_outs,
                         "amount_cents > 0",
                         name: "gift_card_cash_outs_amount_positive"
    add_check_constraint :gift_card_cash_outs,
                         "reversal_of_id IS NULL AND physical_cash_confirmed = FALSE AND physical_cash_confirmed_by_id IS NULL OR reversal_of_id IS NOT NULL AND physical_cash_confirmed = TRUE AND physical_cash_confirmed_by_id IS NOT NULL",
                         name: "gift_card_cash_outs_physical_cash_on_reversal"

    add_column :pos_controlled_actions, :gift_card_cash_out_id, :uuid
    add_index :pos_controlled_actions, :gift_card_cash_out_id, unique: true,
              where: "gift_card_cash_out_id IS NOT NULL",
              name: "index_pos_controlled_actions_on_cash_out"
    add_foreign_key :pos_controlled_actions, :gift_card_cash_outs
    change_column_null :pos_controlled_actions, :pos_transaction_id, true

    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         "action_type IN ('price_override', 'line_discount', 'tax_class_override', 'unlinked_return', 'post_void', 'gift_card_cash_out')",
                         name: "pos_controlled_actions_type_valid"

    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_line_scope"
    add_check_constraint :pos_controlled_actions,
                         <<~SQL.squish,
                           (action_type = 'post_void' AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NOT NULL AND gift_card_cash_out_id IS NULL)
                           OR (action_type = 'gift_card_cash_out' AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NULL AND gift_card_cash_out_id IS NOT NULL)
                           OR (action_type NOT IN ('post_void', 'gift_card_cash_out') AND pos_transaction_line_id IS NOT NULL AND pos_transaction_id IS NOT NULL AND gift_card_cash_out_id IS NULL)
                         SQL
                         name: "pos_controlled_actions_line_scope"

    add_column :pos_reporting_periods, :finalized_stored_value_issuance_cents, :bigint
    add_column :pos_reporting_periods, :finalized_stored_value_payment_cents, :bigint
    add_column :pos_reporting_periods, :finalized_stored_value_refund_cents, :bigint
    add_column :pos_reporting_periods, :finalized_gift_card_cash_out_cents, :bigint
    add_column :pos_reporting_periods, :finalized_gift_card_cash_out_reversal_cents, :bigint
    add_check_constraint :pos_reporting_periods,
                         "finalized_stored_value_issuance_cents IS NULL OR finalized_stored_value_issuance_cents >= 0",
                         name: "pos_reporting_periods_finalized_sv_issuance_nonnegative"
    add_check_constraint :pos_reporting_periods,
                         "finalized_stored_value_payment_cents IS NULL OR finalized_stored_value_payment_cents >= 0",
                         name: "pos_reporting_periods_finalized_sv_payment_nonnegative"
    add_check_constraint :pos_reporting_periods,
                         "finalized_stored_value_refund_cents IS NULL OR finalized_stored_value_refund_cents >= 0",
                         name: "pos_reporting_periods_finalized_sv_refund_nonnegative"
    add_check_constraint :pos_reporting_periods,
                         "finalized_gift_card_cash_out_cents IS NULL OR finalized_gift_card_cash_out_cents >= 0",
                         name: "pos_reporting_periods_finalized_gc_cash_out_nonnegative"
    add_check_constraint :pos_reporting_periods,
                         "finalized_gift_card_cash_out_reversal_cents IS NULL OR finalized_gift_card_cash_out_reversal_cents >= 0",
                         name: "pos_reporting_periods_finalized_gc_cash_out_rev_nonnegative"
  end
end
