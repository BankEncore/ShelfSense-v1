# frozen_string_literal: true

module GiftCards
  class Replace
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      gift_card:,
      performed_by:,
      store:,
      source_id:,
      idempotency_key:,
      reason_code:,
      reason_name_snapshot:,
      number: nil,
      approved_by: nil,
      notes: nil,
      correlation_id: nil
    )
      @gift_card = gift_card
      @performed_by = performed_by
      @store = store
      @source_id = source_id
      @idempotency_key = idempotency_key
      @reason_code = reason_code
      @reason_name_snapshot = reason_name_snapshot
      @number = number
      @approved_by = approved_by
      @notes = notes
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise GiftCards::Error, "reason is required" if @reason_code.to_s.strip.blank?

      payload = {
        original_gift_card_id: @gift_card.id,
        reason_code: @reason_code.to_s
      }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "gift_card_replace",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return GiftCardReplacement.find(op.operation.result_id) if op.operation.result_id

        raise GiftCards::Error, "idempotent replay missing result"
      end

      begin
        result = nil
        GiftCard.transaction do
          original = GiftCard.lock.find(@gift_card.id)
          raise GiftCards::Error, "replaced or closed cards cannot be replaced" if original.replaced? || original.closed?

          account = StoredValueAccount.lock.find(original.stored_value_account_id)
          amount = account.balance_cents
          raise GiftCards::Error, "replacement requires a remaining balance" unless amount.positive?

          replacement_card = ProvisionInstrument.call(
            program: original.gift_card_program,
            store: @store,
            number: @number,
            customer: original.customer
          )
          operation = StoredValue::Post.call(
            operation_type: "transfer",
            store: @store,
            performed_by: @performed_by,
            source_id: @source_id,
            idempotency_key: SecureRandom.uuid_v7,
            entries: [
              { account: account, amount_cents: -amount },
              { account: replacement_card.stored_value_account, amount_cents: amount }
            ],
            reason_code: @reason_code,
            reason_name_snapshot: @reason_name_snapshot,
            notes: @notes,
            outbox_event_type: "gift_card.replaced",
            correlation_id: @correlation_id
          )
          account.reload.close_zero!
          original.update!(status: "replaced", replaced_by: replacement_card)
          replacement = GiftCardReplacement.create!(
            original_gift_card: original,
            replacement_gift_card: replacement_card,
            amount_cents: amount,
            reason_code: @reason_code,
            reason_name_snapshot: @reason_name_snapshot,
            notes: @notes,
            performed_by: @performed_by,
            approved_by: @approved_by,
            stored_value_operation: operation,
            posted_at: Time.current
          )
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "GiftCardReplacement",
            result_id: replacement.id
          )
          result = replacement
        end
        result
      rescue GiftCards::Error, StoredValue::Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "gift_cards.replace",
          outcome: "failed",
          actor_user: @performed_by,
          store: @store,
          subject: @gift_card,
          correlation_id: @correlation_id,
          reason_text: e.message
        )
        raise GiftCards::Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end
  end
end
