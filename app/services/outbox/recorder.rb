# frozen_string_literal: true

module Outbox
  class Recorder
    def self.record!(event_type:, aggregate:, payload:, occurred_at: Time.current, correlation_id: nil, causation_id: nil, origin: "server", schema_version: 1)
      new.record!(
        event_type: event_type,
        aggregate: aggregate,
        payload: payload,
        occurred_at: occurred_at,
        correlation_id: correlation_id,
        causation_id: causation_id,
        origin: origin,
        schema_version: schema_version
      )
    end

    def record!(event_type:, aggregate:, payload:, occurred_at:, correlation_id:, causation_id:, origin:, schema_version:)
      OutboxMessage.create!(
        event_type: event_type,
        schema_version: schema_version,
        aggregate_type: aggregate.class.name,
        aggregate_id: aggregate.id,
        aggregate_version: aggregate.respond_to?(:lock_version) ? aggregate.lock_version : nil,
        occurred_at: occurred_at,
        correlation_id: correlation_id || SecureRandom.uuid_v7,
        causation_id: causation_id,
        origin: origin,
        payload: payload,
        delivery_status: "pending"
      )
    end
  end

  # Minimal at-least-once hook: acknowledge pending messages by id without side effects.
  class Dispatcher
    def self.acknowledge!(limit: 100)
      OutboxMessage.where(delivery_status: "pending").order(:created_at).limit(limit).find_each do |message|
        message.update!(
          delivery_status: "delivered",
          delivered_at: Time.current,
          last_attempted_at: Time.current,
          attempt_count: message.attempt_count + 1
        )
      end
    end
  end
end
