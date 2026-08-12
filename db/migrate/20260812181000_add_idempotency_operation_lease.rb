# frozen_string_literal: true

class AddIdempotencyOperationLease < ActiveRecord::Migration[8.1]
  def change
    add_column :idempotency_operations, :lease_expires_at, :timestamptz
    add_column :idempotency_operations, :lock_version, :integer, null: false, default: 0

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE idempotency_operations
          SET lease_expires_at = created_at
          WHERE status = 'in_flight' AND lease_expires_at IS NULL
        SQL
      end
    end

    add_check_constraint :idempotency_operations,
                         "status <> 'in_flight' OR lease_expires_at IS NOT NULL",
                         name: "idempotency_operations_in_flight_has_lease"
  end
end
