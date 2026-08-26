# frozen_string_literal: true

module Pos
  class PostVoidStoredValue
    def self.copy_rows!(source:, reversal:)
      new(source: source, reversal: reversal, actor: nil, operation: nil).copy_rows!
    end

    def self.reverse!(source:, reversal:, actor:, operation:)
      new(source: source, reversal: reversal, actor: actor, operation: operation).reverse!
    end

    def initialize(source:, reversal:, actor:, operation:)
      @source = source
      @reversal = reversal
      @actor = actor
      @operation = operation
    end

    def copy_rows!
      copy_issuances!
      copy_tender_details!
    end

    def reverse!
      reverse_source_operations!
    rescue StoredValue::Error => e
      raise Pos::Error, post_void_blocked_message(e)
    end

    private

    def copy_issuances!
      @source.pos_stored_value_issuances.ordered.each_with_index do |source_issuance, index|
        @reversal.pos_stored_value_issuances.create!(
          issuance_number: index + 1,
          issuance_type: source_issuance.issuance_type,
          amount_cents: source_issuance.amount_cents,
          gift_card_program: source_issuance.gift_card_program,
          gift_card: source_issuance.gift_card,
          number_authority: source_issuance.number_authority,
          masked_card_snapshot: source_issuance.masked_card_snapshot,
          post_void_source_issuance: source_issuance
        )
      end
    end

    def copy_tender_details!
      @reversal.pos_tenders.ordered.each do |reversal_tender|
        source = reversal_tender.post_void_source_tender
        detail = source&.stored_value_tender_detail
        next if detail.blank?

        reversal_tender.create_stored_value_tender_detail!(
          destination_mode: detail.destination_mode,
          stored_value_account: detail.stored_value_account,
          gift_card: detail.gift_card,
          gift_card_program: detail.gift_card_program,
          masked_card_snapshot: detail.masked_card_snapshot
        )
      end
    end

    def reverse_source_operations!
      operations.each do |original|
        next if original.reversed?

        reversed = StoredValue::Reverse.call(
          operation: original,
          performed_by: @actor,
          source_id: @operation.id,
          idempotency_key: Pos::Support.nested_stored_value_idempotency_key(@operation.id, "reverse", original.id),
          store: @reversal.store
        )
        link_reversal!(original, reversed)
      end
    end

    def operations
      ids = @source.pos_stored_value_issuances.filter_map(&:stored_value_operation_id)
      ids += @source.pos_tenders.filter_map { |tender| tender.stored_value_tender_detail&.stored_value_operation_id }
      StoredValueOperation.where(id: ids).order(:occurred_at, :id).to_a.reverse
    end

    def link_reversal!(original, reversed)
      @reversal.pos_stored_value_issuances.where(post_void_source_issuance_id: original_issuance_ids(original)).find_each do |issuance|
        issuance.update!(stored_value_operation: reversed)
      end
      @reversal.pos_tenders.each do |tender|
        detail = tender.stored_value_tender_detail
        next unless detail
        next unless tender.post_void_source_tender&.stored_value_tender_detail&.stored_value_operation_id == original.id

        detail.update!(stored_value_operation: reversed)
      end
    end

    def original_issuance_ids(original)
      @source.pos_stored_value_issuances.where(stored_value_operation_id: original.id).pluck(:id)
    end

    def post_void_blocked_message(error)
      return error.message unless error.message.to_s.include?("negative")

      downstream = downstream_operation_ids
      suffix = downstream.any? ? " Downstream operations: #{downstream.join(', ')}." : ""
      "Post-void cannot be completed because downstream stored-value activity cannot be fully reversed.#{suffix}"
    end

    def downstream_operation_ids
      account_ids = operations.flat_map { |operation| operation.stored_value_entries.map(&:stored_value_account_id) }.uniq
      return [] if account_ids.empty?

      original_ids = operations.map(&:id)
      StoredValueOperation.where(
        id: StoredValueEntry.where(stored_value_account_id: account_ids).select(:stored_value_operation_id)
      ).where.not(id: original_ids)
       .where.not(operation_type: "reverse")
       .order(:occurred_at, :id)
       .limit(8)
       .pluck(:id)
    end
  end
end
