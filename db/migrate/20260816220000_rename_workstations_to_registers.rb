# frozen_string_literal: true

class RenameWorkstationsToRegisters < ActiveRecord::Migration[8.1]
  PERMISSION_RENAMES = {
    "workstations.view" => [ "registers.view", "registers", "View registers" ],
    "workstations.create" => [ "registers.create", "registers", "Create registers" ],
    "workstations.manage" => [ "registers.manage", "registers", "Manage registers" ],
    "workstations.deactivate" => [ "registers.deactivate", "registers", "Deactivate registers" ]
  }.freeze

  def up
    rename_table :workstations, :registers
    rename_column :audit_events, :workstation_id, :register_id

    if check_constraint_exists?(:registers, name: "workstations_receipt_sequence_nonnegative")
      remove_check_constraint :registers, name: "workstations_receipt_sequence_nonnegative"
    end
    add_check_constraint :registers, "receipt_sequence >= 0", name: "registers_receipt_sequence_nonnegative"

    if index_name_exists?(:registers, "index_workstations_on_store_id_and_code")
      rename_index :registers, "index_workstations_on_store_id_and_code", "index_registers_on_store_id_and_code"
    end

    add_column :registers, :register_number, :string
    backfill_register_numbers
    change_column_null :registers, :register_number, false
    add_index :registers, [ :store_id, :register_number ], unique: true, name: "index_registers_on_store_id_and_register_number"

    rename_permissions
    drop_revoke_permission
  end

  def down
    restore_revoke_permission
    revert_permission_renames

    remove_index :registers, name: "index_registers_on_store_id_and_register_number"
    remove_column :registers, :register_number

    if index_name_exists?(:registers, "index_registers_on_store_id_and_code")
      rename_index :registers, "index_registers_on_store_id_and_code", "index_workstations_on_store_id_and_code"
    end

    if check_constraint_exists?(:registers, name: "registers_receipt_sequence_nonnegative")
      remove_check_constraint :registers, name: "registers_receipt_sequence_nonnegative"
    end
    add_check_constraint :registers, "receipt_sequence >= 0", name: "workstations_receipt_sequence_nonnegative"

    rename_column :audit_events, :register_id, :workstation_id
    rename_table :registers, :workstations
  end

  private

  def backfill_register_numbers
    store_ids = connection.select_values("SELECT DISTINCT store_id FROM registers ORDER BY store_id")
    store_ids.each do |store_id|
      rows = connection.select_all(<<~SQL)
        SELECT id, code
        FROM registers
        WHERE store_id = #{connection.quote(store_id)}
        ORDER BY created_at ASC, id ASC
      SQL

      used = {}
      numeric_rows = []
      other_ids = []

      rows.each do |row|
        code = row["code"].to_s.strip
        if code.match?(/\A\d+\z/)
          numeric_rows << [ row["id"], code ]
        else
          other_ids << row["id"]
        end
      end

      numeric_rows.each do |id, code|
        used[code] = true
        execute(<<~SQL)
          UPDATE registers
          SET register_number = #{connection.quote(code)}
          WHERE id = #{connection.quote(id)}
        SQL
      end

      next_n = 1
      other_ids.each do |id|
        candidate = nil
        loop do
          candidate = format("%02d", next_n)
          next_n += 1
          break unless used[candidate]
        end
        used[candidate] = true
        execute(<<~SQL)
          UPDATE registers
          SET register_number = #{connection.quote(candidate)}
          WHERE id = #{connection.quote(id)}
        SQL
      end
    end
  end

  def rename_permissions
    PERMISSION_RENAMES.each do |old_key, (new_key, group_key, name)|
      execute(<<~SQL)
        UPDATE permissions
        SET key = #{connection.quote(new_key)},
            group_key = #{connection.quote(group_key)},
            name = #{connection.quote(name)},
            updated_at = CURRENT_TIMESTAMP
        WHERE key = #{connection.quote(old_key)}
      SQL
    end
  end

  def revert_permission_renames
    PERMISSION_RENAMES.each do |old_key, (new_key, _group_key, _name)|
      name = case old_key
      when "workstations.view" then "View workstations"
      when "workstations.create" then "Create workstations"
      when "workstations.manage" then "Manage workstations"
      when "workstations.deactivate" then "Deactivate workstations"
      else old_key
      end
      execute(<<~SQL)
        UPDATE permissions
        SET key = #{connection.quote(old_key)},
            group_key = 'workstations',
            name = #{connection.quote(name)},
            updated_at = CURRENT_TIMESTAMP
        WHERE key = #{connection.quote(new_key)}
      SQL
    end
  end

  def drop_revoke_permission
    revoke_id = connection.select_value(<<~SQL)
      SELECT id FROM permissions WHERE key = 'workstations.revoke'
    SQL
    return if revoke_id.blank?

    execute(<<~SQL)
      DELETE FROM role_permissions WHERE permission_id = #{connection.quote(revoke_id)}
    SQL
    execute(<<~SQL)
      DELETE FROM permissions WHERE id = #{connection.quote(revoke_id)}
    SQL
  end

  def restore_revoke_permission
    existing = connection.select_value(<<~SQL)
      SELECT id FROM permissions WHERE key = 'workstations.revoke'
    SQL
    return if existing.present?

    now = connection.quote(Time.current)
    id = connection.quote(SecureRandom.uuid_v7)
    execute(<<~SQL)
      INSERT INTO permissions (id, key, group_key, name, scope_type, active, created_at, updated_at)
      VALUES (
        #{id},
        'workstations.revoke',
        'workstations',
        'Revoke workstations',
        'either',
        TRUE,
        #{now},
        #{now}
      )
    SQL
  end
end
