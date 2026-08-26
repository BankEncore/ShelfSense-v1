# frozen_string_literal: true

module Cash
  module SessionGuard
    module_function

    def lock_open_session!(session)
      locked = PosSession.lock.find(session.id)
      raise Error, "session is not open" unless locked.open?

      locked
    end

    def lock_open_cashier_session!(session, actor)
      locked = Pos::Support.lock_open_cashier_session!(session, actor)
      refuse_commercial_working!(locked)
      locked
    rescue Pos::Denied, Pos::Error => e
      raise Error, e.message
    end

    def refuse_commercial_working!(session)
      working = session.pos_transactions.working.first
      return if working.nil? || !Pos::Support.commercial_content?(working)

      raise Error, "complete or cancel the current transaction before this cash action"
    end

    def session_balance_after(session, delta)
      Pos::SessionTotals.for(session).available_cash_cents + Integer(delta)
    end
  end
end
