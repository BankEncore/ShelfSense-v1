# frozen_string_literal: true

module Cash
  class ReconcileSafe
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      actor:,
      start_count:,
      count_cents:,
      source_id:,
      idempotency_key:,
      reason_code: nil,
      notes: nil,
      approver_username: nil,
      approver_password: nil
    )
      @store = store
      @actor = actor
      @start_count = start_count
      @count_cents = count_cents
      @source_id = source_id
      @idempotency_key = idempotency_key
      @reason_code = reason_code
      @notes = notes
      @approver_username = approver_username
      @approver_password = approver_password
    end

    def call
      counted = Integer(@count_cents)
      raise Error, "count must be a non-negative amount" if counted.negative?
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.reconcile_safe", store: @store
      )
        raise Error, "not authorized to reconcile the safe"
      end
      raise Error, "count is not a safe reconciliation" unless @start_count.purpose == "safe_reconciliation"
      raise Error, "count is not for this store" unless @start_count.cash_location.store_id == @store.id

      payload = { store_id: @store.id, start_count_id: @start_count.id, count_cents: counted }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "cash_reconcile_safe",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return CashCount.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        CashCount.transaction do
          Locations.ensure!(@store)
          safe = CashLocation.lock.find(@start_count.cash_location_id)
          raise Error, "safe is not initialized" unless safe.initialized?
          SnapshotCount.assert_current!(safe, @start_count)

          expected = safe.expected_balance_cents
          variance = counted - expected
          policy = VariancePolicy.for!(
            store: @store,
            actor: @actor,
            variance_cents: variance,
            reason_code: @reason_code,
            notes: @notes,
            approver_username: @approver_username,
            approver_password: @approver_password
          )
          accepted = SnapshotCount.accept!(count: @start_count, total_cents: counted)

          if variance != 0
            operation = Post.call(
              operation_type: "reconcile",
              store: @store,
              performed_by: @actor,
              approved_by: policy.approved_by,
              source_id: SecureRandom.uuid_v7,
              idempotency_key: SecureRandom.uuid_v7,
              reason_code: policy.reason.code,
              reason_name_snapshot: policy.reason.name,
              notes: policy.notes,
              entries: [ { cash_location: safe, amount_cents: variance } ]
            )
            CashReconciliation.create!(
              direction: variance.positive? ? "over" : "short",
              expected_cents: expected,
              counted_cents: counted,
              variance_cents: variance,
              cash_location: safe,
              cash_count: accepted,
              cash_operation: operation
            )
          end

          Audit::Recorder.record!(
            action: "cash.reconcile_safe",
            outcome: "succeeded",
            actor_user: @actor,
            store: @store,
            subject: accepted,
            after_values: { counted_cents: counted, variance_cents: variance }
          )
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "CashCount",
            result_id: accepted.id,
            result_payload: { counted_cents: counted, variance_cents: variance }
          )
          result = accepted
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, Pos::Denied => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "cash.reconcile_safe",
          outcome: "failed",
          actor_user: @actor,
          store: @store,
          reason_text: e.message
        )
        raise Error, e.message
      rescue Idempotency::OperationService::PayloadMismatchError
        raise
      end
    end
  end
end
