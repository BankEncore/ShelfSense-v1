# frozen_string_literal: true

module Cash
  class PrepareDeposit
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      actor:,
      start_count:,
      amount_cents:,
      source_id:,
      idempotency_key:,
      bag_reference: nil
    )
      @store = store
      @actor = actor
      @start_count = start_count
      @amount_cents = amount_cents
      @source_id = source_id
      @idempotency_key = idempotency_key
      @bag_reference = bag_reference.to_s.strip.presence
    end

    def call
      amount = Integer(@amount_cents)
      raise Error, "amount must be positive" unless amount.positive?
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.prepare_deposit", store: @store
      )
        raise Error, "not authorized to prepare a deposit"
      end
      raise Error, "count is not a deposit count" unless @start_count.purpose == "deposit"
      raise Error, "count is not for this store" unless @start_count.cash_location.store_id == @store.id

      payload = {
        store_id: @store.id,
        start_count_id: @start_count.id,
        amount_cents: amount,
        bag_reference: @bag_reference
      }
      op = Idempotency::OperationService.begin!(
        source_id: @source_id,
        operation_type: "cash_prepare_deposit",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return CashDeposit.find(op.operation.result_id) if op.operation.result_id

        raise Error, "idempotent replay missing result"
      end

      begin
        result = nil
        CashDeposit.transaction do
          Locations.ensure!(@store)
          safe = CashLocation.find(@start_count.cash_location_id)
          dit = CashLocation.find_by!(store: @store, location_type: "deposit_in_transit")
          [ safe.id, dit.id ].sort.each { |id| CashLocation.lock.find(id) }
          safe.reload
          dit.reload
          raise Error, "safe is not initialized" unless safe.initialized?
          SnapshotCount.assert_current!(safe, @start_count)
          if amount > safe.expected_balance_cents
            raise Error, "safe does not have enough cash for this deposit"
          end

          occurred_at = Time.current
          business_date = @start_count.business_date || BusinessDate.for_store(@store, at: occurred_at)
          deposit_number = CashDeposit.where(store: @store, business_date: business_date).maximum(:deposit_number).to_i + 1
          accepted = SnapshotCount.accept!(count: @start_count, total_cents: amount)
          operation = Post.call(
            operation_type: "transfer",
            store: @store,
            performed_by: @actor,
            source_id: SecureRandom.uuid_v7,
            idempotency_key: SecureRandom.uuid_v7,
            business_date: business_date,
            occurred_at: occurred_at,
            outbox_event_type: "cash.deposit_prepared",
            entries: [
              { cash_location: safe, amount_cents: -amount },
              { cash_location: dit, amount_cents: amount }
            ]
          )
          CashTransfer.create!(
            transfer_type: "deposit",
            amount_cents: amount,
            source_cash_location: safe,
            destination_cash_location: dit,
            cash_operation: operation
          )
          deposit = CashDeposit.create!(
            store: @store,
            business_date: business_date,
            deposit_number: deposit_number,
            bag_reference: @bag_reference,
            total_cents: amount,
            prepared_by: @actor,
            cash_count: accepted,
            cash_operation: operation
          )
          Audit::Recorder.record!(
            action: "cash.prepare_deposit",
            outcome: "succeeded",
            actor_user: @actor,
            store: @store,
            subject: deposit,
            after_values: { total_cents: amount, deposit_number: deposit_number }
          )
          Idempotency::OperationService.complete!(
            op.operation,
            result_type: "CashDeposit",
            result_id: deposit.id,
            result_payload: { total_cents: amount }
          )
          result = deposit
        end
        result
      rescue Error, ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique => e
        Idempotency::OperationService.fail!(op.operation, message: e.message)
        Audit::Recorder.record!(
          action: "cash.prepare_deposit",
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
