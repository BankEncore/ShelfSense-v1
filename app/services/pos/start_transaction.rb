# frozen_string_literal: true

module Pos
  class StartTransaction
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, actor:, currency_code: nil)
      @session = session
      @actor = actor
      @currency_code = currency_code.presence || SystemSettings.current.base_currency_code
    end

    def call
      PosSession.transaction do
        session = Pos::Support.lock_open_cashier_session!(@session, @actor)
        if session.pos_transactions.working.exists?
          raise Pos::Error, "a working transaction already exists"
        end

        Pos::Support.create_working_transaction!(session: session, currency_code: @currency_code)
      end
    rescue ActiveRecord::RecordNotUnique
      raise Pos::Error, "a working transaction already exists"
    end
  end
end
