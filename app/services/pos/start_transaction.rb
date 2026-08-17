# frozen_string_literal: true

module Pos
  class StartTransaction
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, actor:, currency_code: "USD")
      @session = session
      @actor = actor
      @currency_code = currency_code
    end

    def call
      PosSession.transaction do
        session = PosSession.lock.find(@session.id)
        Pos::Support.authorize!(@actor, session.store)
        Pos::Support.require_active_context!(session.store, session.register)
        Pos::Support.require_session_cashier!(@actor, session)
        raise Pos::Error, "session is not open" unless session.open?
        raise Pos::Error, "reporting period is not open" unless session.reporting_period.open?

        PosTransaction.create!(
          store: session.store,
          register: session.register,
          pos_session: session,
          reporting_period: session.reporting_period,
          cashier_user: session.cashier_user,
          status: "working",
          currency_code: @currency_code
        )
      end
    end
  end
end
