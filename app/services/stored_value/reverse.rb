# frozen_string_literal: true

module StoredValue
  class Reverse
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      operation:,
      performed_by:,
      source_id:,
      idempotency_key:,
      store: nil,
      notes: nil,
      correlation_id: nil
    )
      @original = operation
      @performed_by = performed_by
      @source_id = source_id
      @idempotency_key = idempotency_key
      @store = store || operation.store
      @notes = notes
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Error, "operation is required" if @original.blank?

      original = StoredValueOperation.find(@original.id)
      raise Error, "cannot reverse a reversal" if original.reverse?
      raise Error, "operation already reversed" if original.reversed?

      entries = original.stored_value_entries.order(:entry_sequence).to_a
      Post.call(
        operation_type: "reverse",
        store: @store,
        performed_by: @performed_by,
        source_id: @source_id,
        idempotency_key: @idempotency_key,
        entries: entries.map { |entry| { account: entry.stored_value_account, amount_cents: -entry.amount_cents } },
        reversal_of: original,
        reversal_entry_map: entries.each_with_index.to_h { |entry, index| [ index, entry ] },
        notes: @notes,
        correlation_id: @correlation_id
      )
    end
  end
end
