# frozen_string_literal: true

module Pos
  class AddLinkedReturnLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      transaction:,
      actor:,
      expected_lock_version:,
      original_line:,
      quantity:,
      reason_code:,
      reason_note: nil
    )
      @transaction = transaction
      @actor = actor
      @expected_lock_version = expected_lock_version
      @original_line = original_line
      @quantity = quantity
      @reason_code = reason_code
      @reason_note = reason_note
    end

    def call
      Pos::AddLinkedReturnLines.call(
        transaction: @transaction,
        actor: @actor,
        expected_lock_version: @expected_lock_version,
        items: [
          {
            original_line_id: @original_line.id,
            quantity: @quantity,
            reason_code: @reason_code,
            reason_note: @reason_note
          }
        ]
      ).first
    end
  end
end
