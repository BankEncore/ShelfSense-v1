# frozen_string_literal: true

module Idempotency
  class OperationService
    class PayloadMismatchError < StandardError; end
    class Error < StandardError; end

    STATUSES = %w[in_flight completed failed].freeze
    LEASE_DURATION = 2.minutes

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

        if existing.status == "in_flight"
          reclaimed = reclaim_stale_in_flight!(existing)
          return Result.new(operation: reclaimed, replayed: false) if reclaimed

          raise Error, "idempotency operation is still in flight"
        end

        if existing.status == "failed"
          retried = retry_failed!(existing)
          return Result.new(operation: retried, replayed: false)
        end
      end

      operation = IdempotencyOperation.create!(
        source_id: source_id,
        operation_type: operation_type,
        idempotency_key: idempotency_key,
        payload_hash: hash,
        status: "in_flight",
        lease_expires_at: Time.current + LEASE_DURATION
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
        error_message: nil,
        lease_expires_at: nil
      )
      operation
    end

    def self.fail!(operation, message:)
      operation.update!(
        status: "failed",
        error_message: message,
        completed_at: Time.current,
        lease_expires_at: nil
      )
      operation
    end

    def canonical_hash(payload)
      Digest::SHA256.hexdigest(CanonicalJson.dump(payload))
    end

    private

    def reclaim_stale_in_flight!(operation)
      now = Time.current
      return if operation.lease_expires_at.blank? || operation.lease_expires_at >= now

      updated = IdempotencyOperation.where(
        id: operation.id,
        status: "in_flight",
        lock_version: operation.lock_version
      ).where("lease_expires_at < ?", now).update_all(
        lease_expires_at: now + LEASE_DURATION,
        lock_version: operation.lock_version + 1,
        error_message: nil,
        updated_at: now
      )
      return unless updated == 1

      operation.reload
    end

    def retry_failed!(operation)
      now = Time.current
      updated = IdempotencyOperation.where(
        id: operation.id,
        status: "failed",
        lock_version: operation.lock_version
      ).update_all(
        status: "in_flight",
        lease_expires_at: now + LEASE_DURATION,
        lock_version: operation.lock_version + 1,
        error_message: nil,
        completed_at: nil,
        updated_at: now
      )
      raise Error, "idempotency operation previously failed: #{operation.error_message}" unless updated == 1

      operation.reload
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
