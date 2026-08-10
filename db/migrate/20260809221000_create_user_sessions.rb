# frozen_string_literal: true

class CreateUserSessions < ActiveRecord::Migration[8.1]
  def change
    create_uuid_table :user_sessions do |t|
      t.uuid :user_id, null: false
      t.string :token_digest, null: false
      t.timestamptz :last_seen_at, null: false
      t.timestamptz :expires_at, null: false
      t.timestamptz :revoked_at
      t.uuid :revoked_by_id
      t.inet :ip_address
      t.text :user_agent
      t.timestamptz :created_at, null: false
    end

    add_index :user_sessions, :token_digest, unique: true
    add_index :user_sessions, [ :user_id, :revoked_at ]
    add_index :user_sessions, :expires_at
    add_foreign_key :user_sessions, :users
    add_foreign_key :user_sessions, :users, column: :revoked_by_id
    add_foreign_key :audit_events, :user_sessions
  end
end
