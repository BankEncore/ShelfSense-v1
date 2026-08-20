# frozen_string_literal: true

module Pos
  class OperationLease
    class Error < Pos::Error; end

    Result = Struct.new(:operation, :replayed, keyword_init: true)

    def self.begin!(register_id:, operation_id:, command_payload:, store_id: nil, pos_transaction_id: nil, command_type: PosOperation::COMMAND_TYPE)
      new.begin!(
        register_id: register_id,
        operation_id: operation_id,
        command_payload: command_payload,
        store_id: store_id,
        pos_transaction_id: pos_transaction_id,
        command_type: command_type
      )
    end

    def begin!(register_id:, operation_id:, command_payload:, store_id:, pos_transaction_id:, command_type:)
      hash = Idempotency::CanonicalJson.hash(command_payload)
      existing = PosOperation.find_by(id: operation_id)
      return resolve_existing!(existing, register_id: register_id, command_payload: command_payload, command_type: command_type) if existing

      begin
        create_in_flight!(
          register_id: register_id,
          operation_id: operation_id,
          hash: hash,
          store_id: store_id,
          pos_transaction_id: pos_transaction_id,
          command_type: command_type
        )
      rescue ActiveRecord::RecordNotUnique
        recovered = PosOperation.find_by(id: operation_id) || PosOperation.find_by(
          source_id: register_id,
          command_type: command_type,
          idempotency_key: operation_id
        )
        raise Error, "could not resolve operation uniqueness collision" if recovered.nil?

        resolve_existing!(recovered, register_id: register_id, command_payload: command_payload, command_type: command_type)
      end
    end

    def self.fail!(operation)
      operation.update!(status: "failed", lease_expires_at: nil)
      operation
    end

    private

    def create_in_flight!(register_id:, operation_id:, hash:, store_id:, pos_transaction_id:, command_type:)
      operation = PosOperation.create!(
        id: operation_id,
        command_type: command_type,
        source_id: register_id,
        idempotency_key: operation_id,
        command_payload_hash: hash,
        status: "in_flight",
        lease_expires_at: Time.current + PosOperation::LEASE_DURATION,
        store_id: store_id,
        register_id: register_id,
        pos_transaction_id: pos_transaction_id
      )
      Result.new(operation: operation, replayed: false)
    end

    def resolve_existing!(existing, register_id:, command_payload:, command_type:)
      raise Error, "operation_id reused against another register" if existing.source_id != register_id
      raise Error, "operation_id reused with a different command type" if existing.command_type != command_type
      unless payload_matches?(existing, command_payload, command_type)
        raise Pos::PayloadMismatch, "idempotency key reused with a different payload"
      end
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

      raise Error, "idempotency operation is in an unexpected status"
    end

    def payload_matches?(existing, command_payload, command_type)
      if command_type == PosOperation::COMMAND_TYPE
        Pos::CompleteTransaction.payload_hash_matches?(existing.command_payload_hash, command_payload)
      else
        existing.command_payload_hash == Idempotency::CanonicalJson.hash(command_payload)
      end
    end

    def reclaim_stale_in_flight!(operation)
      now = Time.current
      return if operation.lease_expires_at.blank? || operation.lease_expires_at >= now

      updated = PosOperation.where(
        id: operation.id,
        status: "in_flight",
        lock_version: operation.lock_version
      ).where("lease_expires_at < ?", now).update_all(
        lease_expires_at: now + PosOperation::LEASE_DURATION,
        lock_version: operation.lock_version + 1,
        updated_at: now
      )
      return unless updated == 1

      operation.reload
    end

    def retry_failed!(operation)
      now = Time.current
      updated = PosOperation.where(
        id: operation.id,
        status: "failed",
        lock_version: operation.lock_version
      ).update_all(
        status: "in_flight",
        lease_expires_at: now + PosOperation::LEASE_DURATION,
        lock_version: operation.lock_version + 1,
        updated_at: now
      )
      raise Error, "completion operation previously failed" unless updated == 1

      operation.reload
    end
  end
end
