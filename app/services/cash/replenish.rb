# frozen_string_literal: true

module Cash
  class Replenish
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, actor:, amount_cents:, source_id:, idempotency_key:)
      @session = session
      @actor = actor
      @amount_cents = amount_cents
      @source_id = source_id
      @idempotency_key = idempotency_key
    end

    def call
      amount = Integer(@amount_cents)
      raise Error, "amount must be positive" unless amount.positive?
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.move", store: @session.store
      )
        raise Error, "not authorized to replenish this session"
      end

      CashTransfer.transaction do
        Cash::Locations.ensure!(@session.store)
        safe = CashLocation.lock.find_by!(store: @session.store, location_type: "safe")
        session = SessionGuard.lock_open_session!(@session)
        SessionGuard.refuse_commercial_working!(session)
        if safe.expected_balance_cents < amount
          raise Error, "safe does not have enough cash for this replenishment"
        end

        operation = Post.call(
          operation_type: "transfer",
          store: session.store,
          performed_by: @actor,
          pos_session: session,
          source_id: @source_id,
          idempotency_key: @idempotency_key,
          entries: [
            { cash_location: safe, amount_cents: -amount },
            { pos_session: session, amount_cents: amount, balance_after_cents: SessionGuard.session_balance_after(session, amount) }
          ]
        )
        return operation.cash_transfer if operation.cash_transfer

        CashTransfer.create!(
          transfer_type: "replenishment",
          amount_cents: amount,
          source_cash_location: safe,
          destination_pos_session: session,
          cash_operation: operation
        )
      end
    end
  end
end
