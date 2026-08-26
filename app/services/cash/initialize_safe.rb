# frozen_string_literal: true

module Cash
  class InitializeSafe
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      performed_by:,
      approved_by:,
      count_cents:,
      source_id:,
      idempotency_key:,
      notes: nil,
      business_date: nil
    )
      @store = store
      @performed_by = performed_by
      @approved_by = approved_by
      @count_cents = count_cents
      @source_id = source_id
      @idempotency_key = idempotency_key
      @notes = notes.to_s.strip.presence
      @business_date = business_date
    end

    def call
      count = Integer(@count_cents)
      raise Error, "count must be a non-negative amount" if count.negative?
      raise Error, "approver is required" if @approved_by.blank?
      raise Error, "approver must differ from the performer" if @approved_by.id == @performed_by.id

      unless Authorization::PermissionEvaluator.allowed?(
        user: @performed_by, permission_key: "cash.initialize_safe", store: @store
      )
        raise Error, "not authorized to initialize the safe"
      end
      unless Authorization::PermissionEvaluator.allowed?(
        user: @approved_by, permission_key: "cash.approve_initialize_safe", store: @store
      )
        raise Error, "approver is not authorized to initialize the safe"
      end

      payload = { store_id: @store.id, count_cents: count, notes: @notes }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "cash_initialize_safe",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return CashSafeInitialization.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        CashLocation.transaction do
          Locations.ensure!(@store)
          safe = CashLocation.lock.find_by!(store: @store, location_type: "safe")
          raise Error, "safe is already initialized" if safe.initialized?

          occurred_at = Time.current
          business_date = @business_date || BusinessDate.for_store(@store, at: occurred_at)
          count_record = CashCount.create!(
            purpose: "safe_initialization",
            total_cents: count,
            cash_location: safe,
            status: "accepted"
          )

          operation = if count.positive?
            Post.call(
              operation_type: "initialize_safe",
              store: @store,
              performed_by: @performed_by,
              approved_by: @approved_by,
              source_id: SecureRandom.uuid_v7,
              idempotency_key: SecureRandom.uuid_v7,
              notes: @notes,
              business_date: business_date,
              occurred_at: occurred_at,
              entries: [ { cash_location: safe, amount_cents: count } ]
            )
          else
            empty_zero_operation!(
              idempotency_operation: op.operation,
              business_date: business_date,
              occurred_at: occurred_at
            )
          end

          safe.reload.update!(initialized_at: occurred_at)
          initialization = CashSafeInitialization.create!(
            cash_location: safe,
            cash_count: count_record,
            counted_cents: count,
            notes: @notes,
            cash_operation: operation
          )

          Audit::Recorder.record!(
            action: "cash.initialize_safe",
            outcome: "succeeded",
            actor_user: @performed_by,
            store: @store,
            subject: initialization,
            after_values: { counted_cents: count, cash_location_id: safe.id }
          )

          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "CashSafeInitialization",
            result_id: initialization.id,
            result_payload: { counted_cents: count }
          )

          result = initialization
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::StaleObjectError => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "cash.initialize_safe",
          outcome: "failed",
          actor_user: @performed_by,
          store: @store,
          reason_text: e.message
        )
        raise Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end

    private

    def empty_zero_operation!(idempotency_operation:, business_date:, occurred_at:)
      CashOperation.create!(
        operation_type: "initialize_safe",
        store: @store,
        business_date: business_date,
        occurred_at: occurred_at,
        performed_by: @performed_by,
        approved_by: @approved_by,
        idempotency_operation: idempotency_operation,
        notes: @notes
      )
    end
  end
end
