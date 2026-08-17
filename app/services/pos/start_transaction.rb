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
      Pos::Support.authorize!(@actor, @session.store)
      raise Pos::Error, "session is not open" unless @session.open?
      raise Pos::Error, "reporting period is not open" unless @session.reporting_period.open?

      PosTransaction.create!(
        store: @session.store,
        register: @session.register,
        pos_session: @session,
        reporting_period: @session.reporting_period,
        cashier_user: @actor,
        status: "working",
        currency_code: @currency_code
      )
    end
  end
end
