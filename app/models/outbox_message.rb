# frozen_string_literal: true

class OutboxMessage < ApplicationRecord
  include UuidV7PrimaryKey

  DELIVERY_STATUSES = %w[pending delivered failed].freeze

  validates :event_type, :aggregate_type, :aggregate_id, :occurred_at, :correlation_id, :origin, :delivery_status, presence: true
  validates :delivery_status, inclusion: { in: DELIVERY_STATUSES }
end
