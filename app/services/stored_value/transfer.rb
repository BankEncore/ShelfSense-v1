# frozen_string_literal: true

module StoredValue
  class Transfer
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      from_account:,
      to_account:,
      amount_cents:,
      transfer_type:,
      performed_by:,
      source_id:,
      idempotency_key:,
      store: nil,
      approved_by: nil,
      reason_code: nil,
      reason_name_snapshot: nil,
      notes: nil,
      merge_idempotency_operation: nil,
      correlation_id: nil
    )
      @from_account = from_account
      @to_account = to_account
      @amount_cents = amount_cents
      @transfer_type = transfer_type.to_s
      @performed_by = performed_by
      @source_id = source_id
      @idempotency_key = idempotency_key
      @store = store
      @approved_by = approved_by
      @reason_code = reason_code
      @reason_name_snapshot = reason_name_snapshot
      @notes = notes
      @merge_idempotency_operation = merge_idempotency_operation
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      validate!
      payload = {
        from_account_id: @from_account.id,
        to_account_id: @to_account.id,
        amount_cents: Integer(@amount_cents),
        transfer_type: @transfer_type
      }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "stored_value_transfer",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return StoredValueTransfer.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        StoredValueAccount.transaction do
          ids = [ @from_account.id, @to_account.id ].uniq.sort
          locked = ids.index_with { |id| StoredValueAccount.lock.find(id) }
          source = locked.fetch(@from_account.id)
          destination = locked.fetch(@to_account.id)
          validate_locked!(source, destination)
          amount = Integer(@amount_cents)
          raise Error, "store is required" if @store.blank?

          operation = Post.call(
            operation_type: "transfer",
            store: @store,
            performed_by: @performed_by,
            source_id: @source_id,
            idempotency_key: SecureRandom.uuid_v7,
            entries: [
              { account: source, amount_cents: -amount },
              { account: destination, amount_cents: amount }
            ],
            reason_code: @reason_code,
            reason_name_snapshot: @reason_name_snapshot,
            notes: @notes,
            correlation_id: @correlation_id
          )
          transfer = StoredValueTransfer.create!(
            transfer_type: @transfer_type,
            from_account: source,
            to_account: destination,
            amount_cents: amount,
            source_customer_id: source.customer_id,
            survivor_customer_id: destination.customer_id,
            reason_code: @reason_code,
            reason_name_snapshot: @reason_name_snapshot,
            notes: @notes,
            performed_by: @performed_by,
            approved_by: @approved_by,
            stored_value_operation: operation,
            posted_at: Time.current,
            merge_idempotency_operation: @merge_idempotency_operation
          )
          close_source_if_needed!(source.reload, amount)
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "StoredValueTransfer",
            result_id: transfer.id
          )
          result = transfer
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "stored_value.transfer",
          outcome: "failed",
          actor_user: @performed_by,
          store: @store,
          subject: @from_account,
          correlation_id: @correlation_id,
          reason_text: e.message
        )
        raise Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end

    private

    def validate!
      raise Error, "invalid transfer type" unless StoredValueTransfer::TRANSFER_TYPES.include?(@transfer_type)
      raise Error, "amount must be positive" unless Integer(@amount_cents).positive?
      raise Error, "source and destination must differ" if @from_account.id == @to_account.id
      if @from_account.account_type != @to_account.account_type || @from_account.currency_code != @to_account.currency_code
        raise Error, "cross-type conversion is prohibited"
      end
      unless @transfer_type == "customer_merge"
        raise Error, "second-user approval is required" if @approved_by.blank?
        raise Error, "approver cannot be the performer" if @approved_by.id == @performed_by.id
        raise Error, "reason is required" if @reason_code.to_s.strip.blank?
      end
    end

    def validate_locked!(source, destination)
      raise Error, "source account is closed" if source.closed?
      raise Error, "destination account is closed" if destination.closed?
      raise Error, "insufficient source balance" if source.balance_cents < Integer(@amount_cents)
    end

    def close_source_if_needed!(source, _amount)
      source.close_zero! if source.balance_cents.zero?
    end
  end
end
