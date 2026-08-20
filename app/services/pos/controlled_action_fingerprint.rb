# frozen_string_literal: true

module Pos
  class ControlledActionFingerprint
    SCHEMA_VERSION = PosControlledAction::FINGERPRINT_SCHEMA_VERSION

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(action_type:, transaction_id:, material_values:, reason_code:, reason_note: nil, line_id: nil)
      @action_type = action_type
      @transaction_id = transaction_id
      @line_id = line_id
      @material_values = material_values
      @reason_code = reason_code
      @reason_note = reason_note
    end

    def call
      payload = {
        "action_type" => @action_type,
        "transaction_id" => @transaction_id.to_s,
        "material_values" => @material_values,
        "reason_code" => @reason_code,
        "fingerprint_schema_version" => SCHEMA_VERSION
      }
      payload["line_id"] = @line_id.to_s if @line_id.present?
      payload["reason_note"] = @reason_note.to_s if @reason_code == "other"
      Idempotency::CanonicalJson.hash(payload)
    end
  end
end
