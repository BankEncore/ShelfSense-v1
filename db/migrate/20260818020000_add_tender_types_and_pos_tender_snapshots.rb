# frozen_string_literal: true

class AddTenderTypesAndPosTenderSnapshots < ActiveRecord::Migration[8.1]
  SYSTEM_IDENTITIES = [
    { code: "cash", name: "Cash", category: "cash", policy: "omitted" },
    { code: "card", name: "External Card", category: "card", policy: "optional" },
    { code: "check", name: "Check", category: "check", policy: "optional" }
  ].freeze

  def up
    create_uuid_table :tender_types do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :behavioral_category, null: false
      t.boolean :active, null: false, default: true
      t.string :external_reference_policy, null: false
      t.boolean :system_protected, null: false, default: false
      t.integer :lock_version, null: false, default: 0
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :tender_types, :code, unique: true, name: "index_tender_types_on_code"
    add_check_constraint :tender_types,
                         "behavioral_category IN ('cash', 'card', 'check', 'other')",
                         name: "tender_types_category_valid"
    add_check_constraint :tender_types,
                         "external_reference_policy IN ('omitted', 'optional', 'required')",
                         name: "tender_types_reference_policy_valid"

    cash_id = seed_system_identities!

    add_column :pos_tenders, :tender_type_id, :uuid
    add_column :pos_tenders, :tender_number, :integer
    add_column :pos_tenders, :tender_name, :string
    add_column :pos_tenders, :behavioral_category, :string
    add_column :pos_tenders, :external_reference, :text

    execute <<~SQL
      UPDATE pos_tenders
      SET tender_type_id = #{quote(cash_id)},
          tender_number = 1,
          tender_name = 'Cash',
          behavioral_category = 'cash'
    SQL

    change_column_null :pos_tenders, :tender_type_id, false
    change_column_null :pos_tenders, :tender_number, false
    change_column_null :pos_tenders, :tender_name, false
    change_column_null :pos_tenders, :behavioral_category, false
    change_column_null :pos_tenders, :amount_presented_cents, true
    change_column_null :pos_tenders, :change_cents, true
    change_column_default :pos_tenders, :change_cents, from: 0, to: nil

    add_index :pos_tenders, :tender_type_id
    add_index :pos_tenders, %i[pos_transaction_id tender_number], unique: true,
              name: "index_pos_tenders_on_transaction_and_number"
    add_index :pos_tenders, :pos_transaction_id, unique: true,
              where: "behavioral_category = 'cash' AND direction = 'payment'",
              name: "index_pos_tenders_one_cash_payment"

    add_foreign_key :pos_tenders, :tender_types, on_delete: :restrict

    remove_check_constraint :pos_tenders, name: "pos_tenders_type_valid"
    remove_check_constraint :pos_tenders, name: "pos_tenders_nonnegative"
    add_check_constraint :pos_tenders,
                         "tender_number >= 1",
                         name: "pos_tenders_number_positive"
    add_check_constraint :pos_tenders,
                         "behavioral_category IN ('cash', 'card', 'check', 'other')",
                         name: "pos_tenders_category_valid"
    add_check_constraint :pos_tenders,
                         "amount_cents >= 0",
                         name: "pos_tenders_amount_nonnegative"
    add_check_constraint :pos_tenders,
                         <<~SQL.squish,
                           (behavioral_category = 'cash'
                            AND amount_presented_cents IS NOT NULL
                            AND change_cents IS NOT NULL
                            AND amount_presented_cents >= 0
                            AND change_cents >= 0
                            AND amount_presented_cents = (amount_cents + change_cents))
                           OR
                           (behavioral_category IN ('card', 'check', 'other')
                            AND amount_presented_cents IS NULL
                            AND change_cents IS NULL)
                         SQL
                         name: "pos_tenders_cash_presented_matches"
  end

  def down
    remove_check_constraint :pos_tenders, name: "pos_tenders_cash_presented_matches"
    remove_check_constraint :pos_tenders, name: "pos_tenders_amount_nonnegative"
    remove_check_constraint :pos_tenders, name: "pos_tenders_category_valid"
    remove_check_constraint :pos_tenders, name: "pos_tenders_number_positive"
    add_check_constraint :pos_tenders,
                         "amount_cents >= 0 AND amount_presented_cents >= 0 AND change_cents >= 0",
                         name: "pos_tenders_nonnegative"
    add_check_constraint :pos_tenders, "tender_type IN ('cash')", name: "pos_tenders_type_valid"

    remove_foreign_key :pos_tenders, :tender_types
    remove_index :pos_tenders, name: "index_pos_tenders_one_cash_payment"
    remove_index :pos_tenders, name: "index_pos_tenders_on_transaction_and_number"
    remove_index :pos_tenders, :tender_type_id

    change_column_default :pos_tenders, :change_cents, from: nil, to: 0
    execute "UPDATE pos_tenders SET change_cents = 0 WHERE change_cents IS NULL"
    execute "UPDATE pos_tenders SET amount_presented_cents = 0 WHERE amount_presented_cents IS NULL"
    change_column_null :pos_tenders, :change_cents, false
    change_column_null :pos_tenders, :amount_presented_cents, false

    remove_column :pos_tenders, :external_reference
    remove_column :pos_tenders, :behavioral_category
    remove_column :pos_tenders, :tender_name
    remove_column :pos_tenders, :tender_number
    remove_column :pos_tenders, :tender_type_id
    drop_table :tender_types
  end

  private

  def seed_system_identities!
    cash_id = nil
    now = quote(Time.current)
    SYSTEM_IDENTITIES.each do |attrs|
      id = SecureRandom.uuid_v7
      cash_id = id if attrs[:code] == "cash"
      execute <<~SQL
        INSERT INTO tender_types (
          id, code, name, behavioral_category, active, external_reference_policy,
          system_protected, lock_version, created_at, updated_at
        ) VALUES (
          #{quote(id)}, #{quote(attrs[:code])}, #{quote(attrs[:name])},
          #{quote(attrs[:category])}, TRUE, #{quote(attrs[:policy])},
          TRUE, 0, #{now}, #{now}
        )
      SQL
    end
    cash_id
  end
end
