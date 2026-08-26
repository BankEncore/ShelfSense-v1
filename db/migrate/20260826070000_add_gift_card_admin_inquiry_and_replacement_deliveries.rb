# frozen_string_literal: true

class AddGiftCardAdminInquiryAndReplacementDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_index :gift_cards, [ :number_prefix, :number_last_four ],
              name: "index_gift_cards_on_prefix_and_last_four"

    change_column_null :pos_gift_card_credential_deliveries, :pos_transaction_id, true
    add_column :pos_gift_card_credential_deliveries, :gift_card_id, :uuid
    add_index :pos_gift_card_credential_deliveries, :gift_card_id, unique: true,
              where: "gift_card_id IS NOT NULL",
              name: "index_pos_gc_credential_deliveries_on_gift_card"
    add_foreign_key :pos_gift_card_credential_deliveries, :gift_cards
    add_check_constraint :pos_gift_card_credential_deliveries,
                         "(pos_transaction_id IS NOT NULL AND gift_card_id IS NULL) OR (pos_transaction_id IS NULL AND gift_card_id IS NOT NULL)",
                         name: "pos_gc_credential_deliveries_one_subject"
  end
end
