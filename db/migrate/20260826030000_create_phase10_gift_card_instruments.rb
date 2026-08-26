# frozen_string_literal: true

class CreatePhase10GiftCardInstruments < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :gift_card_programs do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :number_authority, null: false
      t.string :prefix, null: false
      t.integer :number_length, null: false, default: 20
      t.string :check_digit_algorithm, null: false, default: "luhn"
      t.boolean :reload_allowed, null: false, default: true
      t.bigint :minimum_activation_cents
      t.bigint :maximum_balance_cents
      t.string :cash_out_policy, null: false
      t.bigint :cash_out_threshold_cents
      t.boolean :cash_out_threshold_inclusive, null: false, default: true
      t.boolean :cash_out_approval_required, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :gift_card_programs, :code, unique: true
    add_index :gift_card_programs, :prefix, unique: true
    add_check_constraint :gift_card_programs,
                         "number_authority IN ('system_generated', 'manual_external')",
                         name: "gift_card_programs_authority_valid"
    add_check_constraint :gift_card_programs,
                         "check_digit_algorithm = 'luhn'",
                         name: "gift_card_programs_check_digit_valid"
    add_check_constraint :gift_card_programs,
                         "number_length = 20",
                         name: "gift_card_programs_length_phase10"
    add_check_constraint :gift_card_programs,
                         "cash_out_policy IN ('prohibited', 'permitted_when_eligible', 'required_on_request_when_eligible')",
                         name: "gift_card_programs_cash_out_policy_valid"
    add_check_constraint :gift_card_programs,
                         "prefix ~ '^[0-9]+$'",
                         name: "gift_card_programs_prefix_numeric"

    create_uuid_table :gift_cards do |t|
      t.uuid :gift_card_program_id, null: false
      t.uuid :stored_value_account_id, null: false
      t.text :number, null: false
      t.string :number_digest, null: false
      t.string :number_prefix, null: false
      t.string :number_last_four, null: false
      t.string :status, null: false, default: "active"
      t.uuid :customer_id
      t.timestamptz :activated_at, null: false
      t.uuid :activated_store_id, null: false
      t.uuid :replaced_by_id
      t.timestamptz :closed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :gift_cards, :number_digest, unique: true
    add_index :gift_cards, :stored_value_account_id, unique: true
    add_index :gift_cards, :gift_card_program_id
    add_index :gift_cards, :customer_id
    add_foreign_key :gift_cards, :gift_card_programs
    add_foreign_key :gift_cards, :stored_value_accounts
    add_foreign_key :gift_cards, :customers
    add_foreign_key :gift_cards, :stores, column: :activated_store_id
    add_foreign_key :gift_cards, :gift_cards, column: :replaced_by_id
    add_check_constraint :gift_cards,
                         "status IN ('active', 'suspended', 'replaced', 'closed')",
                         name: "gift_cards_status_valid"
    add_check_constraint :gift_cards,
                         "char_length(number_last_four) = 4",
                         name: "gift_cards_last_four_length"

    create_uuid_table :gift_card_replacements do |t|
      t.uuid :original_gift_card_id, null: false
      t.uuid :replacement_gift_card_id, null: false
      t.bigint :amount_cents, null: false
      t.string :reason_code, null: false
      t.string :reason_name_snapshot, null: false
      t.text :notes
      t.uuid :performed_by_id, null: false
      t.uuid :approved_by_id
      t.uuid :stored_value_operation_id
      t.timestamptz :posted_at, null: false
      t.uuid :reversal_of_id
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :gift_card_replacements, :stored_value_operation_id, unique: true, where: "stored_value_operation_id IS NOT NULL"
    add_index :gift_card_replacements, :reversal_of_id, unique: true, where: "reversal_of_id IS NOT NULL"
    add_index :gift_card_replacements, :original_gift_card_id, unique: true,
              where: "reversal_of_id IS NULL",
              name: "index_gift_card_replacements_one_effective_per_original"
    add_index :gift_card_replacements, :replacement_gift_card_id
    add_foreign_key :gift_card_replacements, :gift_cards, column: :original_gift_card_id
    add_foreign_key :gift_card_replacements, :gift_cards, column: :replacement_gift_card_id
    add_foreign_key :gift_card_replacements, :users, column: :performed_by_id
    add_foreign_key :gift_card_replacements, :users, column: :approved_by_id
    add_foreign_key :gift_card_replacements, :stored_value_operations
    add_foreign_key :gift_card_replacements, :gift_card_replacements, column: :reversal_of_id
    add_check_constraint :gift_card_replacements,
                         "amount_cents > 0",
                         name: "gift_card_replacements_amount_positive"
    add_check_constraint :gift_card_replacements,
                         "original_gift_card_id <> replacement_gift_card_id",
                         name: "gift_card_replacements_cards_differ"
    add_check_constraint :gift_card_replacements,
                         "approved_by_id IS NULL OR approved_by_id <> performed_by_id",
                         name: "gift_card_replacements_approver_differs"
  end
end
