# frozen_string_literal: true

class CreatePhase3IdempotencyAndOutbox < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :idempotency_operations do |t|
      t.uuid :source_id, null: false
      t.string :operation_type, null: false
      t.uuid :idempotency_key, null: false
      t.string :payload_hash, null: false
      t.string :status, null: false, default: "in_flight"
      t.string :result_type
      t.uuid :result_id
      t.jsonb :result_payload, null: false, default: {}
      t.text :error_message
      t.timestamptz :completed_at
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end

    add_index :idempotency_operations,
              %i[source_id operation_type idempotency_key],
              unique: true,
              name: "index_idempotency_operations_on_scope_key"
    add_check_constraint :idempotency_operations,
                         "status IN ('in_flight', 'completed', 'failed')",
                         name: "idempotency_operations_status_valid"

    create_uuid_table :outbox_messages do |t|
      t.string :event_type, null: false
      t.integer :schema_version, null: false, default: 1
      t.string :aggregate_type, null: false
      t.uuid :aggregate_id, null: false
      t.integer :aggregate_version
      t.timestamptz :occurred_at, null: false
      t.uuid :correlation_id, null: false
      t.uuid :causation_id
      t.string :origin, null: false, default: "server"
      t.jsonb :payload, null: false, default: {}
      t.string :delivery_status, null: false, default: "pending"
      t.integer :attempt_count, null: false, default: 0
      t.timestamptz :delivered_at
      t.timestamptz :last_attempted_at
      t.timestamptz :created_at, null: false
    end

    add_index :outbox_messages, %i[delivery_status created_at],
              name: "index_outbox_messages_on_delivery_status_and_created_at"
    add_index :outbox_messages, :event_type
    add_check_constraint :outbox_messages,
                         "delivery_status IN ('pending', 'delivered', 'failed')",
                         name: "outbox_messages_delivery_status_valid"
  end
end
