# frozen_string_literal: true

class AddCompletedTransactionHistory < ActiveRecord::Migration[8.1]
  def up
    add_column :pos_transactions, :cashier_name_snapshot, :string

    execute <<~SQL
      UPDATE pos_transactions AS t
      SET cashier_name_snapshot = a.actor_label
      FROM (
        SELECT DISTINCT ON (subject_id)
          subject_id, actor_label
        FROM audit_events
        WHERE action = 'pos.transaction_completed'
          AND outcome = 'succeeded'
          AND subject_type = 'PosTransaction'
        ORDER BY subject_id, occurred_at ASC, id ASC
      ) AS a
      WHERE t.id = a.subject_id
        AND t.status = 'completed'
        AND t.cashier_name_snapshot IS NULL
    SQL

    add_index :pos_transactions, %i[store_id completed_at id],
              order: { completed_at: :desc, id: :desc },
              where: "status = 'completed'",
              name: "index_pos_transactions_completed_recent"
    add_index :pos_transactions, %i[store_id business_date completed_at id],
              order: { completed_at: :desc, id: :desc },
              where: "status = 'completed'",
              name: "index_pos_transactions_completed_business_date"
  end

  def down
    remove_index :pos_transactions, name: "index_pos_transactions_completed_business_date"
    remove_index :pos_transactions, name: "index_pos_transactions_completed_recent"
    remove_column :pos_transactions, :cashier_name_snapshot
  end
end
