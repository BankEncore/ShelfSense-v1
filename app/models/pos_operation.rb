# frozen_string_literal: true

class PosOperation < ApplicationRecord
  STATUSES = %w[in_flight completed failed].freeze
  COMMAND_TYPE = "pos.complete_transaction"
  FACT_TYPE = "pos.transaction_completed"
  LEASE_DURATION = 2.minutes

  belongs_to :pos_transaction, optional: true
  belongs_to :store, optional: true
  belongs_to :register, optional: true

  validates :command_type, :source_id, :idempotency_key, :command_payload_hash, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: { scope: %i[source_id command_type] }
end
