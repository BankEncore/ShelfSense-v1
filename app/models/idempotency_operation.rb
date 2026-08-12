# frozen_string_literal: true

class IdempotencyOperation < ApplicationRecord
  include UuidV7PrimaryKey

  STATUSES = Idempotency::OperationService::STATUSES

  validates :source_id, :operation_type, :idempotency_key, :payload_hash, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
