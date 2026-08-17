# frozen_string_literal: true

module Pos
  class CloseSession
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(session:, actor:, expected_lock_version:, closed_at: Time.current)
      @session = session
      @actor = actor
      @expected_lock_version = expected_lock_version
      @closed_at = closed_at
    end

    def call
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

        session.update!(status: "closed", closed_at: @closed_at)
        session
      end
    end
  end
end
