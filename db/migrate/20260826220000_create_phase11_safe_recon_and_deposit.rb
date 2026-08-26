# frozen_string_literal: true

class CreatePhase11SafeReconAndDeposit < ActiveRecord::Migration[8.1]
  def change
    add_column :cash_counts, :business_date, :date
    add_index :cash_counts, [ :cash_location_id, :purpose, :business_date ],
              name: "index_cash_counts_on_location_purpose_date"

    create_uuid_table :cash_deposits do |t|
      t.uuid :store_id, null: false
      t.date :business_date, null: false
      t.integer :deposit_number, null: false
      t.string :bag_reference
      t.bigint :total_cents, null: false
      t.uuid :prepared_by_id, null: false
      t.uuid :approved_by_id
      t.uuid :cash_count_id, null: false
      t.uuid :cash_operation_id, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :cash_deposits, :cash_operation_id, unique: true
    add_index :cash_deposits, :cash_count_id
    add_index :cash_deposits, :store_id
    add_index :cash_deposits, [ :store_id, :business_date, :deposit_number ],
              unique: true, name: "index_cash_deposits_on_store_date_number"
    add_foreign_key :cash_deposits, :stores
    add_foreign_key :cash_deposits, :users, column: :prepared_by_id
    add_foreign_key :cash_deposits, :users, column: :approved_by_id
    add_foreign_key :cash_deposits, :cash_counts
    add_foreign_key :cash_deposits, :cash_operations
    add_check_constraint :cash_deposits, "total_cents > 0", name: "cash_deposits_total_positive"
    add_check_constraint :cash_deposits, "deposit_number > 0", name: "cash_deposits_number_positive"
  end
end
