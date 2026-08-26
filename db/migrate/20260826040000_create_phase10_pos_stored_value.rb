# frozen_string_literal: true

class CreatePhase10PosStoredValue < ActiveRecord::Migration[8.1]
  def change
    add_column :pos_transactions, :stored_value_issuance_cents, :bigint, null: false, default: 0
    add_column :pos_transactions, :customer_id, :uuid
    add_index :pos_transactions, :customer_id
    add_foreign_key :pos_transactions, :customers

    remove_check_constraint :pos_transactions, name: "pos_transactions_signed_net_matches_components"
    add_check_constraint :pos_transactions,
                         "signed_net_cents = (subtotal_cents - discount_cents + tax_cents + stored_value_issuance_cents - return_total_cents)",
                         name: "pos_transactions_signed_net_matches_components"

    add_column :tender_types, :stored_value_account_type, :string
    add_column :tender_types, :allows_original_tender_refund, :boolean, null: false, default: false
    add_column :tender_types, :allows_generic_refund_destination, :boolean, null: false, default: false
    add_column :tender_types, :allows_refund_instrument_replacement, :boolean, null: false, default: false

    remove_check_constraint :tender_types, name: "tender_types_category_valid"
    add_check_constraint :tender_types,
                         "behavioral_category IN ('cash', 'card', 'check', 'other', 'stored_value')",
                         name: "tender_types_category_valid"
    add_check_constraint :tender_types,
                         "(behavioral_category = 'stored_value' AND stored_value_account_type IN ('store_credit', 'trade_credit', 'gift_card')) OR (behavioral_category <> 'stored_value' AND stored_value_account_type IS NULL)",
                         name: "tender_types_sv_account_type_matches"

    remove_check_constraint :pos_tenders, name: "pos_tenders_category_valid"
    add_check_constraint :pos_tenders,
                         "behavioral_category IN ('cash', 'card', 'check', 'other', 'stored_value')",
                         name: "pos_tenders_category_valid"

    remove_check_constraint :pos_tenders, name: "pos_tenders_cash_presented_matches"
    add_check_constraint :pos_tenders,
                         <<~SQL.squish,
                           (behavioral_category = 'cash' AND direction = 'payment' AND amount_presented_cents IS NOT NULL AND change_cents IS NOT NULL AND amount_presented_cents >= 0 AND change_cents >= 0 AND amount_presented_cents = (amount_cents + change_cents))
                           OR (behavioral_category = 'cash' AND direction = 'refund' AND amount_presented_cents IS NULL AND change_cents IS NULL)
                           OR (behavioral_category IN ('card', 'check', 'other', 'stored_value') AND amount_presented_cents IS NULL AND change_cents IS NULL)
                         SQL
                         name: "pos_tenders_cash_presented_matches"

    create_uuid_table :pos_stored_value_issuances do |t|
      t.uuid :pos_transaction_id, null: false
      t.integer :issuance_number, null: false
      t.string :issuance_type, null: false
      t.bigint :amount_cents, null: false
      t.uuid :gift_card_program_id
      t.uuid :gift_card_id
      t.string :number_authority, null: false
      t.text :pending_card_number
      t.string :pending_card_number_digest
      t.string :pending_card_number_prefix
      t.string :pending_card_number_last_four
      t.uuid :stored_value_operation_id
      t.uuid :post_void_source_issuance_id
      t.string :masked_card_snapshot
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_stored_value_issuances, [ :pos_transaction_id, :issuance_number ], unique: true,
              name: "index_pos_sv_issuances_on_txn_and_number"
    add_index :pos_stored_value_issuances, :stored_value_operation_id, unique: true,
              where: "stored_value_operation_id IS NOT NULL",
              name: "index_pos_sv_issuances_on_operation"
    add_index :pos_stored_value_issuances, :pending_card_number_digest, unique: true,
              where: "pending_card_number_digest IS NOT NULL",
              name: "index_pos_sv_issuances_on_pending_digest"
    add_index :pos_stored_value_issuances, :gift_card_program_id
    add_index :pos_stored_value_issuances, :gift_card_id
    add_index :pos_stored_value_issuances, :post_void_source_issuance_id
    add_foreign_key :pos_stored_value_issuances, :pos_transactions
    add_foreign_key :pos_stored_value_issuances, :gift_card_programs
    add_foreign_key :pos_stored_value_issuances, :gift_cards
    add_foreign_key :pos_stored_value_issuances, :stored_value_operations
    add_foreign_key :pos_stored_value_issuances, :pos_stored_value_issuances, column: :post_void_source_issuance_id
    add_check_constraint :pos_stored_value_issuances,
                         "issuance_type IN ('activation', 'reload')",
                         name: "pos_sv_issuances_type_valid"
    add_check_constraint :pos_stored_value_issuances,
                         "number_authority IN ('system_generated', 'manual_external')",
                         name: "pos_sv_issuances_authority_valid"
    add_check_constraint :pos_stored_value_issuances,
                         "amount_cents > 0",
                         name: "pos_sv_issuances_amount_positive"
    add_check_constraint :pos_stored_value_issuances,
                         "issuance_type <> 'reload' OR gift_card_id IS NOT NULL",
                         name: "pos_sv_issuances_reload_has_card"

    create_uuid_table :pos_stored_value_tender_details do |t|
      t.uuid :pos_tender_id, null: false
      t.uuid :stored_value_operation_id
      t.uuid :stored_value_account_id
      t.uuid :gift_card_id
      t.string :destination_mode, null: false
      t.uuid :gift_card_program_id
      t.text :pending_card_number
      t.string :pending_card_number_digest
      t.string :pending_card_number_prefix
      t.string :pending_card_number_last_four
      t.string :masked_card_snapshot
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :pos_stored_value_tender_details, :pos_tender_id, unique: true
    add_index :pos_stored_value_tender_details, :stored_value_operation_id, unique: true,
              where: "stored_value_operation_id IS NOT NULL",
              name: "index_pos_sv_tender_details_on_operation"
    add_index :pos_stored_value_tender_details, :pending_card_number_digest, unique: true,
              where: "pending_card_number_digest IS NOT NULL",
              name: "index_pos_sv_tender_details_on_pending_digest"
    add_index :pos_stored_value_tender_details, :stored_value_account_id
    add_index :pos_stored_value_tender_details, :gift_card_id
    add_index :pos_stored_value_tender_details, :gift_card_program_id
    add_foreign_key :pos_stored_value_tender_details, :pos_tenders
    add_foreign_key :pos_stored_value_tender_details, :stored_value_operations
    add_foreign_key :pos_stored_value_tender_details, :stored_value_accounts
    add_foreign_key :pos_stored_value_tender_details, :gift_cards
    add_foreign_key :pos_stored_value_tender_details, :gift_card_programs
    add_check_constraint :pos_stored_value_tender_details,
                         "destination_mode IN ('existing_account', 'customer_store_credit', 'new_gift_card')",
                         name: "pos_sv_tender_details_mode_valid"
  end
end
