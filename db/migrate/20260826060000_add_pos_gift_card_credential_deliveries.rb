# frozen_string_literal: true

class AddPosGiftCardCredentialDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :pos_gift_card_credential_deliveries do |t|
      t.uuid :pos_transaction_id, null: false
      t.timestamptz :delivered_at, null: false
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_gift_card_credential_deliveries, :pos_transaction_id, unique: true,
              name: "index_pos_gc_credential_deliveries_on_transaction"
    add_foreign_key :pos_gift_card_credential_deliveries, :pos_transactions
  end
end
