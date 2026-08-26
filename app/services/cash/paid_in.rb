# frozen_string_literal: true

module Cash
  class PaidIn
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, actor:, amount_cents:, reason_code:, source_id:, idempotency_key:, notes: nil)
      @session = session
      @actor = actor
      @amount_cents = amount_cents
      @reason_code = reason_code
      @notes = notes.to_s.strip.presence
      @source_id = source_id
      @idempotency_key = idempotency_key
    end

    def call
      amount = Integer(@amount_cents)
      raise Error, "amount must be positive" unless amount.positive?
      unless Authorization::PermissionEvaluator.allowed?(
        user: @actor, permission_key: "cash.paid_in", store: @session.store
      )
        raise Error, "not authorized to record a paid-in"
      end
      reason = ActivityReasons.require!(@reason_code, "paid_in")
      if reason.notes_required && @notes.blank?
        raise Error, "notes are required"
      end

      CashPaidIn.transaction do
        session = SessionGuard.lock_open_cashier_session!(@session, @actor)
        operation = Post.call(
          operation_type: "paid_in",
          store: session.store,
          performed_by: @actor,
          pos_session: session,
          source_id: @source_id,
          idempotency_key: @idempotency_key,
          reason_code: reason.code,
          reason_name_snapshot: reason.name,
          notes: @notes,
          entries: [ {
            pos_session: session,
            amount_cents: amount,
            balance_after_cents: SessionGuard.session_balance_after(session, amount)
          } ]
        )
        return operation.cash_paid_in if operation.cash_paid_in

        CashPaidIn.create!(
          pos_session: session,
          amount_cents: amount,
          reason_code: reason.code,
          reason_name_snapshot: reason.name,
          notes: @notes,
          cash_operation: operation
        )
      end
    rescue Pos::Denied => e
      raise Error, e.message
    end
  end
end
