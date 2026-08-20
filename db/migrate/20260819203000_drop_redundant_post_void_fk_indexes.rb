# frozen_string_literal: true

class DropRedundantPostVoidFkIndexes < ActiveRecord::Migration[8.1]
  def up
    remove_index :pos_transactions, name: "index_pos_transactions_on_post_void_of_transaction_id", if_exists: true
    remove_index :pos_transaction_lines, name: "index_pos_transaction_lines_on_post_void_source_line_id", if_exists: true
    remove_index :pos_tenders, name: "index_pos_tenders_on_post_void_source_tender_id", if_exists: true
  end

  def down
    add_index :pos_transactions, :post_void_of_transaction_id,
              name: "index_pos_transactions_on_post_void_of_transaction_id"
    add_index :pos_transaction_lines, :post_void_source_line_id,
              name: "index_pos_transaction_lines_on_post_void_source_line_id"
    add_index :pos_tenders, :post_void_source_tender_id,
              name: "index_pos_tenders_on_post_void_source_tender_id"
  end
end
