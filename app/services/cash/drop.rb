# frozen_string_literal: true

module Cash
  class Drop
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
        user: @actor, permission_key: "pos.transact", store: @session.store
      )
        raise Error, "not authorized to drop cash from this session"
      end

      CashTransfer.transaction do
        Cash::Locations.ensure!(@session.store)
        safe = CashLocation.lock.find_by!(store: @session.store, location_type: "safe")
        session = SessionGuard.lock_open_cashier_session!(@session, @actor)
        AvailableCash.assert!(session, amount)
        operation = Post.call(
          operation_type: "transfer",
          store: session.store,
          performed_by: @actor,
          pos_session: session,
          source_id: @source_id,
          idempotency_key: @idempotency_key,
          entries: [
            { pos_session: session, amount_cents: -amount, balance_after_cents: SessionGuard.session_balance_after(session, -amount) },
            { cash_location: safe, amount_cents: amount }
          ]
        )
        return operation.cash_transfer if operation.cash_transfer

        CashTransfer.create!(
          transfer_type: "drop",
          amount_cents: amount,
          source_pos_session: session,
          destination_cash_location: safe,
          cash_operation: operation
        )
      end
    rescue Pos::Denied => e
      raise Error, e.message
    end
  end
end
