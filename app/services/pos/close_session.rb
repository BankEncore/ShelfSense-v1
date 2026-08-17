# frozen_string_literal: true

module Pos
  class CloseSession
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, actor:, expected_lock_version:, closing_count_cents:, closed_at: Time.current)
      @session = session
      @actor = actor
      @expected_lock_version = expected_lock_version
      @closing_count_cents = closing_count_cents
      @closed_at = closed_at
    end

    def call
      count_cents = Pos::Support.parse_nonnegative_cents!(@closing_count_cents, "closing count")

      PosSession.transaction do
        session = PosSession.lock.find(@session.id)
        Pos::Support.authorize!(@actor, session.store)
        Pos::Support.require_active_context!(session.store, session.register)
        Pos::Support.require_session_cashier!(@actor, session)
        raise Pos::Error, "session is not open" unless session.open?
        if session.lock_version != @expected_lock_version.to_i
          raise Pos::StaleObject, "stale lock_version"
        end
        if session.pos_transactions.working.exists?
          raise Pos::Error, "session has a working transaction"
        end

        expected_cents = Pos::SessionTotals.for(session).expected_cash_cents
        variance_cents = count_cents - expected_cents
        session.update!(
          status: "closed",
          closed_at: @closed_at,
          closing_expected_cash_cents: expected_cents,
          closing_count_cents: count_cents,
          closing_variance_cents: variance_cents
        )
        Audit::Recorder.record!(
          action: "pos.session.closed",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: session.store,
          register: session.register,
          subject: session,
          after_values: {
            closing_count_cents: session.closing_count_cents,
            closing_expected_cash_cents: session.closing_expected_cash_cents,
            closing_variance_cents: session.closing_variance_cents
          }
        )
        session
      end
    end
  end
end
