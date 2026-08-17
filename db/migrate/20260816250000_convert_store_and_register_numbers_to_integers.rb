# frozen_string_literal: true

class ConvertStoreAndRegisterNumbersToIntegers < ActiveRecord::Migration[8.1]
  def up
    preflight_positive_integers!(:stores, :store_number)
    preflight_positive_integers!(:registers, :register_number)
    preflight_store_collisions!
    preflight_register_collisions!

    remove_index :stores, name: "index_stores_on_lower_store_number"
    change_column :stores, :store_number, :integer, using: "store_number::integer"
    add_index :stores, :store_number, unique: true
    add_check_constraint :stores, "store_number > 0", name: "stores_store_number_positive"

    change_column :registers, :register_number, :integer, using: "register_number::integer"
    add_check_constraint :registers, "register_number > 0", name: "registers_register_number_positive"

    change_column :pos_transactions, :store_number_snapshot, :integer, using: "store_number_snapshot::integer"
    change_column :pos_transactions, :register_number_snapshot, :integer, using: "register_number_snapshot::integer"

    remove_check_constraint :pos_transactions, name: "pos_transactions_status_null_rules"
    add_check_constraint :pos_transactions, <<~SQL.squish, name: "pos_transactions_status_null_rules"
      (status = 'working' AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL
        AND occurred_at IS NULL AND business_date IS NULL AND completed_at IS NULL AND cancelled_at IS NULL)
      OR (status = 'completed' AND receipt_sequence IS NOT NULL AND store_number_snapshot IS NOT NULL AND register_number_snapshot IS NOT NULL
        AND occurred_at IS NOT NULL AND business_date IS NOT NULL AND completed_at IS NOT NULL AND cancelled_at IS NULL)
      OR (status = 'cancelled' AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL
        AND occurred_at IS NULL AND business_date IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL)
    SQL

    ensure_deprecated_revoke_permission!
  end

  def down
    remove_check_constraint :pos_transactions, name: "pos_transactions_status_null_rules"
    add_check_constraint :pos_transactions, <<~SQL.squish, name: "pos_transactions_status_null_rules"
      (status = 'working' AND receipt_sequence IS NULL AND store_number_snapshot IS NULL AND register_number_snapshot IS NULL AND completed_at IS NULL AND cancelled_at IS NULL)
      OR (status = 'completed' AND receipt_sequence IS NOT NULL AND store_number_snapshot IS NOT NULL AND register_number_snapshot IS NOT NULL AND completed_at IS NOT NULL AND cancelled_at IS NULL)
      OR (status = 'cancelled' AND receipt_sequence IS NULL AND completed_at IS NULL AND cancelled_at IS NOT NULL)
    SQL

    change_column :pos_transactions, :register_number_snapshot, :string, using: "register_number_snapshot::text"
    change_column :pos_transactions, :store_number_snapshot, :string, using: "store_number_snapshot::text"

    remove_check_constraint :registers, name: "registers_register_number_positive"
    change_column :registers, :register_number, :string, using: "register_number::text"

    remove_check_constraint :stores, name: "stores_store_number_positive"
    remove_index :stores, :store_number
    change_column :stores, :store_number, :string, using: "store_number::text"
    add_index :stores, "lower(store_number)", unique: true, name: "index_stores_on_lower_store_number"
  end

  private

  def preflight_positive_integers!(table, column)
    invalid = connection.select_values(<<~SQL)
      SELECT #{column}
      FROM #{table}
      WHERE #{column} IS NULL
         OR btrim(#{column}::text) !~ '^[0-9]+$'
         OR CAST(btrim(#{column}::text) AS integer) <= 0
    SQL
    return if invalid.empty?

    raise "Cannot convert #{table}.#{column} to a positive integer: #{invalid.uniq.take(10).join(", ")}"
  end

  def preflight_store_collisions!
    collisions = connection.select_all(<<~SQL)
      SELECT CAST(store_number AS integer) AS n, COUNT(*) AS c
      FROM stores
      GROUP BY CAST(store_number AS integer)
      HAVING COUNT(*) > 1
    SQL
    return if collisions.none?

    raise "store_number collision after integer conversion: #{collisions.map { |row| row["n"] }.join(", ")}"
  end

  def preflight_register_collisions!
    collisions = connection.select_all(<<~SQL)
      SELECT store_id, CAST(register_number AS integer) AS n, COUNT(*) AS c
      FROM registers
      GROUP BY store_id, CAST(register_number AS integer)
      HAVING COUNT(*) > 1
    SQL
    return if collisions.none?

    raise "register_number collision after integer conversion for store/number pairs"
  end

  def ensure_deprecated_revoke_permission!
    existing = connection.select_value(<<~SQL)
      SELECT id FROM permissions WHERE key = 'workstations.revoke'
    SQL
    if existing.present?
      execute(<<~SQL)
        UPDATE permissions
        SET active = FALSE,
            name = 'Revoke workstations (deprecated)',
            updated_at = CURRENT_TIMESTAMP
        WHERE key = 'workstations.revoke'
      SQL
      return
    end

    now = connection.quote(Time.current)
    id = connection.quote(SecureRandom.uuid_v7)
    execute(<<~SQL)
      INSERT INTO permissions (id, key, group_key, name, scope_type, active, created_at, updated_at)
      VALUES (
        #{id},
        'workstations.revoke',
        'workstations',
        'Revoke workstations (deprecated)',
        'either',
        FALSE,
        #{now},
        #{now}
      )
    SQL
  end
end
