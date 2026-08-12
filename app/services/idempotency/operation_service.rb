# frozen_string_literal: true

module Idempotency
  class OperationService
    class PayloadMismatchError < StandardError; end
    class Error < StandardError; end

    STATUSES = %w[in_flight completed failed].freeze

    Result = Struct.new(:operation, :replayed, keyword_init: true)

    def self.begin!(source_id:, operation_type:, idempotency_key:, payload:)
      new.begin!(
        source_id: source_id,
        operation_type: operation_type,
        idempotency_key: idempotency_key,
        payload: payload
      )
    end

    def begin!(source_id:, operation_type:, idempotency_key:, payload:)
      hash = canonical_hash(payload)
      existing = IdempotencyOperation.find_by(
        source_id: source_id,
        operation_type: operation_type,
        idempotency_key: idempotency_key
      )

      if existing
        raise PayloadMismatchError, "idempotency key reused with a different payload" if existing.payload_hash != hash
        return Result.new(operation: existing, replayed: true) if existing.status == "completed"
        raise Error, "idempotency operation is still in flight" if existing.status == "in_flight"
        raise Error, "idempotency operation previously failed: #{existing.error_message}" if existing.status == "failed"
      end

      operation = IdempotencyOperation.create!(
        source_id: source_id,
        operation_type: operation_type,
        idempotency_key: idempotency_key,
        payload_hash: hash,
        status: "in_flight"
      )
      Result.new(operation: operation, replayed: false)
    rescue ActiveRecord::RecordNotUnique
      begin!(source_id: source_id, operation_type: operation_type, idempotency_key: idempotency_key, payload: payload)
    end

    def self.complete!(operation, result_type:, result_id:, result_payload: {})
      operation.update!(
        status: "completed",
        result_type: result_type,
        result_id: result_id,
        result_payload: result_payload,
        completed_at: Time.current,
        error_message: nil
      )
      operation
    end

    def self.fail!(operation, message:)
      operation.update!(
        status: "failed",
        error_message: message,
        completed_at: Time.current
      )
      operation
    end

    def canonical_hash(payload)
      Digest::SHA256.hexdigest(CanonicalJson.dump(payload))
    end
  end

  module CanonicalJson
    module_function

    def dump(value)
      JSON.generate(normalize(value))
    end

    def normalize(value)
      case value
      when Hash
        value.keys.sort_by(&:to_s).each_with_object({}) do |key, memo|
          memo[key.to_s] = normalize(value[key])
        end
      when Array
        value.map { |item| normalize(item) }
      when Symbol
        value.to_s
      when Time, ActiveSupport::TimeWithZone
        value.utc.iso8601(6)
      when Date
        value.iso8601
      when BigDecimal
        value.to_s("F")
      else
        value
      end
    end
  end
end
