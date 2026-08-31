# frozen_string_literal: true

module Pos
  class FinalizeReportingPeriod
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(period:, actor:, expected_lock_version:)
      @period = period
      @actor = actor
      @expected_lock_version = expected_lock_version
    end

    def call
      PosReportingPeriod.transaction do
        period = PosReportingPeriod.lock.find(@period.id)
        Pos::Support.authorize!(@actor, period.store)
        Pos::Support.require_active_context!(period.store, period.register)
        return period if period.finalized?

        raise Pos::Error, "reporting period is not open" unless period.open?
        if period.lock_version != @expected_lock_version.to_i
          raise Pos::StaleObject, "stale lock_version"
        end
        if period.pos_sessions.open.exists?
          raise Pos::Error, "reporting period has an open session"
        end
        if period.pos_transactions.working.exists?
          raise Pos::Error, "reporting period has a working transaction"
        end
        if incomplete_sessions?(period)
          raise Pos::Error, "reporting period has a session without closing cash snapshots"
        end

        snapshot = Pos::PeriodTotals.for(period).snapshot
        period.update!(
          snapshot.merge(
            status: "finalized",
            closed_at: Time.current,
            finalized_by: @actor
          )
        )
        Audit::Recorder.record!(
          action: "pos.reporting_period.finalized",
          outcome: "succeeded",
          actor_user: @actor,
          actor_label: @actor.display_name,
          store: period.store,
          register: period.register,
          subject: period,
          after_values: snapshot.merge(finalized_by_user_id: @actor.id)
        )
        period
      end
    end

    private

    def incomplete_sessions?(period)
      period.pos_sessions.where(
        "status <> 'closed' OR closing_expected_cash_cents IS NULL OR closing_count_cents IS NULL OR closing_variance_cents IS NULL"
      ).exists?
    end
  end
end
