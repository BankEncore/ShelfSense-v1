# frozen_string_literal: true

module Pos
  class ControlledActionFingerprint
    SCHEMA_VERSION = PosControlledAction::FINGERPRINT_SCHEMA_VERSION

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(action_type:, material_values:, reason_code:, reason_note: nil, transaction_id: nil, line_id: nil, cash_out_id: nil, cash_paid_out_id: nil)
      @action_type = action_type
      @transaction_id = transaction_id
      @line_id = line_id
      @cash_out_id = cash_out_id
      @cash_paid_out_id = cash_paid_out_id
      @material_values = material_values
      @reason_code = reason_code
      @reason_note = reason_note
    end

    def call
      payload = {
        "action_type" => @action_type,
        "material_values" => @material_values,
        "reason_code" => @reason_code,
        "fingerprint_schema_version" => SCHEMA_VERSION
      }
      payload["transaction_id"] = @transaction_id.to_s if @transaction_id.present?
      payload["cash_out_id"] = @cash_out_id.to_s if @cash_out_id.present?
      payload["cash_paid_out_id"] = @cash_paid_out_id.to_s if @cash_paid_out_id.present?
      payload["line_id"] = @line_id.to_s if @line_id.present?
      payload["reason_note"] = @reason_note.to_s if @reason_code == "other"
      Idempotency::CanonicalJson.hash(payload)
    end
  end
end
