# frozen_string_literal: true

class AddCashCountSupersededUniqueness < ActiveRecord::Migration[8.1]
  def change
    add_index :cash_counts, :superseded_count_id,
              unique: true,
              where: "superseded_count_id IS NOT NULL",
              name: "index_cash_counts_on_superseded_count_id"
  end
end
