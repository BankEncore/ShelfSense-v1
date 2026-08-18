# frozen_string_literal: true

module Pos
  class ResumeOrStartTransaction
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
        session = Pos::Support.lock_open_cashier_session!(@session, @actor)
        session.pos_transactions.working.first ||
          Pos::Support.create_working_transaction!(session: session, currency_code: @currency_code)
      end
    rescue ActiveRecord::RecordNotUnique
      PosTransaction.working.find_by!(pos_session_id: @session.id)
    end
  end
end
