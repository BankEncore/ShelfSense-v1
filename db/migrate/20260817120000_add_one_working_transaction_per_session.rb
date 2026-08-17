# frozen_string_literal: true

class AddOneWorkingTransactionPerSession < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_pos_transactions_one_working_per_session"

  def up
    duplicates = connection.select_all(<<~SQL.squish)
      SELECT pos_session_id::text AS pos_session_id, COUNT(*) AS working_count
      FROM pos_transactions
      WHERE status = 'working'
      GROUP BY pos_session_id
      HAVING COUNT(*) > 1
    SQL

    if duplicates.any?
      details = duplicates.map { |row| "#{row.fetch("pos_session_id")} (#{row.fetch("working_count")})" }.join(", ")
      raise <<~MSG.squish
        Cannot add #{INDEX_NAME}: these sessions already have more than one working
        pos_transaction: #{details}. Resolve the duplicates before migrating;
        do not pick a survivor automatically.
      MSG
    end

    add_index :pos_transactions, :pos_session_id,
              unique: true,
              where: "status = 'working'",
              name: INDEX_NAME
  end

  def down
    remove_index :pos_transactions, name: INDEX_NAME
  end
end
