# frozen_string_literal: true

class AddPosControlledActions < ActiveRecord::Migration[8.1]
  def up
    create_uuid_table :pos_controlled_actions do |t|
      t.references :pos_transaction, type: :uuid, null: false, foreign_key: true
      t.references :pos_transaction_line, type: :uuid, foreign_key: true
      t.string :action_type, null: false
      t.references :performed_by_user, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :performed_by_name_snapshot, null: false
      t.references :approved_by_user, type: :uuid, foreign_key: { to_table: :users }
      t.string :approved_by_name_snapshot
      t.string :reason_code, null: false
      t.string :reason_name_snapshot, null: false
      t.text :reason_note
      t.string :policy_result, null: false
      t.string :policy_version, null: false
      t.string :fingerprint_schema_version, null: false
      t.string :action_fingerprint, null: false
      t.jsonb :material_values, null: false, default: {}
      t.timestamptz :executed_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :pos_controlled_actions, %i[pos_transaction_line_id action_type],
              unique: true,
              where: "pos_transaction_line_id IS NOT NULL",
              name: "index_pos_controlled_actions_effective_line"

    add_check_constraint :pos_controlled_actions,
                         "action_type IN ('price_override', 'line_discount', 'tax_class_override')",
                         name: "pos_controlled_actions_type_valid"
    add_check_constraint :pos_controlled_actions,
                         "policy_result IN ('direct', 'approval_required')",
                         name: "pos_controlled_actions_policy_valid"
    add_check_constraint :pos_controlled_actions,
                         "(policy_result = 'approval_required' AND approved_by_user_id IS NOT NULL AND approved_by_name_snapshot IS NOT NULL) OR (policy_result = 'direct' AND approved_by_user_id IS NULL AND approved_by_name_snapshot IS NULL)",
                         name: "pos_controlled_actions_approver_matches_policy"
    add_check_constraint :pos_controlled_actions,
                         "approved_by_user_id IS NULL OR approved_by_user_id <> performed_by_user_id",
                         name: "pos_controlled_actions_approver_not_performer"
    add_check_constraint :pos_controlled_actions,
                         "pos_transaction_line_id IS NOT NULL",
                         name: "pos_controlled_actions_line_present"
  end

  def down
    drop_table :pos_controlled_actions
  end
end
