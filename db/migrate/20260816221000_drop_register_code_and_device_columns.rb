# frozen_string_literal: true

class DropRegisterCodeAndDeviceColumns < ActiveRecord::Migration[8.1]
  def up
    if index_name_exists?(:registers, "index_registers_on_store_id_and_code")
      remove_index :registers, name: "index_registers_on_store_id_and_code"
    end

    remove_column :registers, :code
    remove_column :registers, :activated_at
    remove_column :registers, :revoked_at
    remove_column :registers, :last_seen_at
  end

  def down
    add_column :registers, :code, :string
    add_column :registers, :activated_at, :timestamptz
    add_column :registers, :revoked_at, :timestamptz
    add_column :registers, :last_seen_at, :timestamptz

    execute(<<~SQL)
      UPDATE registers
      SET code = register_number
      WHERE code IS NULL
    SQL

    change_column_null :registers, :code, false
    add_index :registers, [ :store_id, :code ], unique: true, name: "index_registers_on_store_id_and_code"
  end
end
