# frozen_string_literal: true

class CreatePhase11NonSaleCash < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :cash_paid_ins do |t|
      t.uuid :pos_session_id, null: false
      t.bigint :amount_cents, null: false
      t.string :reason_code, null: false
      t.string :reason_name_snapshot, null: false
      t.text :notes
      t.uuid :cash_operation_id, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_paid_ins, :cash_operation_id, unique: true
    add_index :cash_paid_ins, :pos_session_id
    add_foreign_key :cash_paid_ins, :pos_sessions
    add_foreign_key :cash_paid_ins, :cash_operations
    add_check_constraint :cash_paid_ins, "amount_cents > 0", name: "cash_paid_ins_amount_positive"

    create_uuid_table :cash_paid_outs do |t|
      t.uuid :pos_session_id, null: false
      t.bigint :amount_cents, null: false
      t.string :reason_code, null: false
      t.string :reason_name_snapshot, null: false
      t.text :notes
      t.uuid :cash_operation_id, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_paid_outs, :cash_operation_id, unique: true
    add_index :cash_paid_outs, :pos_session_id
    add_foreign_key :cash_paid_outs, :pos_sessions
    add_foreign_key :cash_paid_outs, :cash_operations
    add_check_constraint :cash_paid_outs, "amount_cents > 0", name: "cash_paid_outs_amount_positive"

    add_column :pos_controlled_actions, :cash_paid_out_id, :uuid
    add_index :pos_controlled_actions, :cash_paid_out_id, unique: true,
              where: "cash_paid_out_id IS NOT NULL",
              name: "index_pos_controlled_actions_on_paid_out"
    add_foreign_key :pos_controlled_actions, :cash_paid_outs

    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         "action_type IN ('price_override', 'line_discount', 'tax_class_override', 'unlinked_return', 'post_void', 'gift_card_cash_out', 'cash_paid_out')",
                         name: "pos_controlled_actions_type_valid"

    remove_check_constraint :pos_controlled_actions, name: "pos_controlled_actions_line_scope"
    add_check_constraint :pos_controlled_actions,
                         <<~SQL.squish,
                           (action_type = 'post_void' AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NOT NULL AND gift_card_cash_out_id IS NULL AND cash_paid_out_id IS NULL)
                           OR (action_type = 'gift_card_cash_out' AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NULL AND gift_card_cash_out_id IS NOT NULL AND cash_paid_out_id IS NULL)
                           OR (action_type = 'cash_paid_out' AND pos_transaction_line_id IS NULL AND pos_transaction_id IS NULL AND gift_card_cash_out_id IS NULL AND cash_paid_out_id IS NOT NULL)
                           OR (action_type NOT IN ('post_void', 'gift_card_cash_out', 'cash_paid_out') AND pos_transaction_line_id IS NOT NULL AND pos_transaction_id IS NOT NULL AND gift_card_cash_out_id IS NULL AND cash_paid_out_id IS NULL)
                         SQL
                         name: "pos_controlled_actions_line_scope"
  end
end
