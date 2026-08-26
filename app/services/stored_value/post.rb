# frozen_string_literal: true

module StoredValue
  class Post
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      operation_type:,
      store:,
      performed_by:,
      source_id:,
      idempotency_key:,
      entries:,
      business_date: nil,
      occurred_at: nil,
      pos_session: nil,
      reason_code: nil,
      reason_name_snapshot: nil,
      notes: nil,
      reversal_of: nil,
      reversal_entry_map: {},
      outbox_event_type: nil,
      correlation_id: nil
    )
      @operation_type = operation_type.to_s
      @store = store
      @performed_by = performed_by
      @source_id = source_id
      @idempotency_key = idempotency_key
      @entries = Array(entries)
      @business_date = business_date
      @occurred_at = occurred_at
      @pos_session = pos_session
      @reason_code = reason_code
      @reason_name_snapshot = reason_name_snapshot
      @notes = notes
      @reversal_of = reversal_of
      @reversal_entry_map = reversal_entry_map
      @outbox_event_type = outbox_event_type
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Error, "actor is required" if @performed_by.blank?
      raise Error, "store is required" if @store.blank?
      raise Error, "idempotency key is required" if @idempotency_key.blank?
      raise Error, "source id is required" if @source_id.blank?
      raise Error, "at least one entry is required" if @entries.empty?

      payload = command_payload
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "stored_value_post",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return StoredValueOperation.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        StoredValueAccount.transaction do
          occurred_at = @occurred_at || Time.current
          business_date = @business_date || BusinessDate.for_store(@store, at: occurred_at)
          account_ids = @entries.map { |entry| account_for(entry).id }.uniq.sort
          locked = account_ids.index_with { |id| StoredValueAccount.lock.find(id) }

          posted = []
          @entries.each_with_index do |entry, index|
            account = locked.fetch(account_for(entry).id)
            amount = Integer(entry.fetch(:amount_cents))
            raise Error, "entry amount must be nonzero" if amount.zero?
            raise Error, "closed accounts cannot receive entries" if account.closed?
            raise Error, "currency mismatch" if posted.any? && account.currency_code != posted.first[:account].currency_code

            next_balance = account.balance_cents + amount
            raise Error, "balance cannot be negative" if next_balance.negative?
            if amount.positive? && @reversal_of.blank?
              GiftCards::MaximumBalance.assert!(account: account, next_balance_cents: next_balance)
            end

            account.apply_posted_balance!(next_balance)
            posted << {
              account: account,
              amount_cents: amount,
              balance_after_cents: next_balance,
              reversal_of: @reversal_entry_map[index]
            }
          end

          if @operation_type == "transfer"
            net = posted.sum { |row| row[:amount_cents] }
            raise Error, "transfer entries must net to zero" unless net.zero?
            raise Error, "transfer requires at least two entries" if posted.size < 2
          end

          operation = StoredValueOperation.create!(
            operation_type: @operation_type,
            store: @store,
            business_date: business_date,
            occurred_at: occurred_at,
            performed_by: @performed_by,
            pos_session: @pos_session,
            idempotency_operation: op.operation,
            reversal_of: @reversal_of,
            reason_code: @reason_code,
            reason_name_snapshot: @reason_name_snapshot,
            notes: @notes
          )

          posted.each_with_index do |row, sequence|
            StoredValueEntry.create!(
              stored_value_operation: operation,
              stored_value_account: row[:account],
              entry_sequence: sequence,
              amount_cents: row[:amount_cents],
              balance_after_cents: row[:balance_after_cents],
              reversal_of: row[:reversal_of]
            )
          end

          Audit::Recorder.record!(
            action: "stored_value.post",
            outcome: "succeeded",
            actor_user: @performed_by,
            store: @store,
            subject: operation,
            correlation_id: @correlation_id,
            after_values: {
              operation_type: operation.operation_type,
              account_ids: posted.map { |row| row[:account].id },
              amounts_cents: posted.map { |row| row[:amount_cents] }
            }
          )

          Outbox::Recorder.record!(
            event_type: @outbox_event_type || StoredValue::OUTBOX_EVENT_TYPES.fetch(@operation_type),
            aggregate: operation,
            payload: {
              operation_id: operation.id,
              operation_type: operation.operation_type,
              store_id: @store.id,
              business_date: business_date.iso8601,
              entries: posted.map { |row|
                {
                  account_id: row[:account].id,
                  amount_cents: row[:amount_cents],
                  balance_after_cents: row[:balance_after_cents]
                }
              }
            },
            occurred_at: occurred_at,
            correlation_id: @correlation_id
          )

          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "StoredValueOperation",
            result_id: operation.id,
            result_payload: { operation_type: operation.operation_type }
          )

          result = operation
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "stored_value.post",
          outcome: "failed",
          actor_user: @performed_by,
          store: @store,
          subject: @reversal_of,
          correlation_id: @correlation_id,
          reason_text: e.message
        )
        raise Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end

    private

    def account_for(entry)
      entry[:account] || StoredValueAccount.find(entry.fetch(:stored_value_account_id))
    end

    def command_payload
      {
        operation_type: @operation_type,
        store_id: @store.id,
        pos_session_id: @pos_session&.id,
        reversal_of_id: @reversal_of&.id,
        entries: @entries.map { |entry|
          {
            stored_value_account_id: account_for(entry).id,
            amount_cents: Integer(entry.fetch(:amount_cents))
          }
        }
      }
    end
  end
end
