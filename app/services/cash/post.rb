# frozen_string_literal: true

module Cash
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
      approved_by: nil,
      reason_code: nil,
      reason_name_snapshot: nil,
      notes: nil,
      reversal_of: nil,
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
      @approved_by = approved_by
      @reason_code = reason_code
      @reason_name_snapshot = reason_name_snapshot
      @notes = notes
      @reversal_of = reversal_of
      @outbox_event_type = outbox_event_type
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Error, "actor is required" if @performed_by.blank?
      raise Error, "store is required" if @store.blank?
      raise Error, "idempotency key is required" if @idempotency_key.blank?
      raise Error, "source id is required" if @source_id.blank?
      raise Error, "at least one entry is required" if @entries.empty?
      if @approved_by.present? && @approved_by.id == @performed_by.id
        raise Error, "approver must differ from the performer"
      end

      payload = command_payload
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "cash_post",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return CashOperation.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        CashOperation.transaction do
          occurred_at = @occurred_at || Time.current
          business_date = @business_date || BusinessDate.for_store(@store, at: occurred_at)
          locked_locations, locked_sessions = lock_targets!

          posted = []
          @entries.each do |entry|
            amount = Integer(entry.fetch(:amount_cents))
            raise Error, "entry amount must be nonzero" if amount.zero?

            location = target_location(entry, locked_locations)
            session = target_session(entry, locked_sessions)
            if location.nil? == session.nil?
              raise Error, "exactly one of cash_location or pos_session is required"
            end

            next_balance = if entry.key?(:balance_after_cents)
              Integer(entry.fetch(:balance_after_cents))
            elsif location
              location.expected_balance_cents + amount
            else
              raise Error, "session entry requires balance_after_cents"
            end
            raise Error, "balance cannot be negative" if next_balance.negative?

            location.apply_posted_balance!(next_balance) if location

            posted << {
              cash_location: location,
              pos_session: session,
              amount_cents: amount,
              balance_after_cents: next_balance,
              reversal_of: entry[:reversal_of]
            }
          end

          if @operation_type == "transfer"
            net = posted.sum { |row| row[:amount_cents] }
            raise Error, "transfer entries must net to zero" unless net.zero?
            raise Error, "transfer requires at least two entries" if posted.size < 2
          end

          operation = CashOperation.create!(
            operation_type: @operation_type,
            store: @store,
            business_date: business_date,
            occurred_at: occurred_at,
            performed_by: @performed_by,
            approved_by: @approved_by,
            pos_session: @pos_session,
            idempotency_operation: op.operation,
            reversal_of: @reversal_of,
            reason_code: @reason_code,
            reason_name_snapshot: @reason_name_snapshot,
            notes: @notes
          )

          posted.each_with_index do |row, sequence|
            CashEntry.create!(
              cash_operation: operation,
              entry_sequence: sequence,
              amount_cents: row[:amount_cents],
              balance_after_cents: row[:balance_after_cents],
              pos_session: row[:pos_session],
              cash_location: row[:cash_location],
              reversal_of: row[:reversal_of]
            )
          end

          Audit::Recorder.record!(
            action: "cash.post",
            outcome: "succeeded",
            actor_user: @performed_by,
            store: @store,
            subject: operation,
            correlation_id: @correlation_id,
            after_values: {
              operation_type: operation.operation_type,
              amounts_cents: posted.map { |row| row[:amount_cents] }
            }
          )

          Outbox::Recorder.record!(
            event_type: @outbox_event_type || Cash::OUTBOX_EVENT_TYPES.fetch(@operation_type),
            aggregate: operation,
            payload: {
              operation_id: operation.id,
              operation_type: operation.operation_type,
              store_id: @store.id,
              business_date: business_date.iso8601,
              entries: posted.map { |row|
                {
                  cash_location_id: row[:cash_location]&.id,
                  pos_session_id: row[:pos_session]&.id,
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
            result_type: "CashOperation",
            result_id: operation.id,
            result_payload: { operation_type: operation.operation_type }
          )

          result = operation
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "cash.post",
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

    def lock_targets!
      location_ids = @entries.filter_map { |entry| location_id_for(entry) }.uniq.sort
      session_ids = @entries.filter_map { |entry| session_id_for(entry) }.uniq.sort
      locked_locations = location_ids.index_with { |id| CashLocation.lock.find(id) }
      locked_sessions = session_ids.index_with { |id| PosSession.lock.find(id) }
      [ locked_locations, locked_sessions ]
    end

    def location_id_for(entry)
      entry[:cash_location]&.id || entry[:cash_location_id]
    end

    def session_id_for(entry)
      entry[:pos_session]&.id || entry[:pos_session_id]
    end

    def target_location(entry, locked)
      id = location_id_for(entry)
      id && locked.fetch(id)
    end

    def target_session(entry, locked)
      id = session_id_for(entry)
      id && locked.fetch(id)
    end

    def command_payload
      {
        operation_type: @operation_type,
        store_id: @store.id,
        pos_session_id: @pos_session&.id,
        approved_by_id: @approved_by&.id,
        reversal_of_id: @reversal_of&.id,
        entries: @entries.map { |entry|
          {
            cash_location_id: location_id_for(entry),
            pos_session_id: session_id_for(entry),
            amount_cents: Integer(entry.fetch(:amount_cents)),
            balance_after_cents: entry[:balance_after_cents]
          }
        }
      }
    end
  end
end
