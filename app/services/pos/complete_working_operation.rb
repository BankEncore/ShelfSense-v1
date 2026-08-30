# frozen_string_literal: true

module Pos
  class CompleteWorkingOperation
    SCHEMA_VERSION = 1

    def self.call(operation:, fact_type:, facts:)
      posted_at = Time.current
      envelope = {
        "operation_id" => operation.id,
        "fact_type" => fact_type,
        "schema_version" => SCHEMA_VERSION,
        "pos_transaction_id" => operation.pos_transaction_id,
        "posted_at" => posted_at.iso8601(6),
        "facts" => facts.deep_stringify_keys
      }

      operation.update!(
        status: "completed",
        fact_type: fact_type,
        schema_version: SCHEMA_VERSION,
        envelope: envelope,
        envelope_hash: Idempotency::CanonicalJson.hash(envelope),
        posted_at: posted_at,
        lease_expires_at: nil
      )
      operation
    end
  end
end
