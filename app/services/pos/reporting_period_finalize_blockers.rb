# frozen_string_literal: true

module Pos
  # Read-only finalize blockers for S9 status and S10 confirmation GET.
  class ReportingPeriodFinalizeBlockers
    Result = Data.define(:blockers, :warnings, :ready?)

    def self.call(period:)
      new(period: period).call
    end

    def initialize(period:)
      @period = period
    end

    def call
      blockers = []
      warnings = []

      unless @period.open?
        blockers << "Reporting period is not open."
        return Result.new(blockers: blockers, warnings: warnings, ready?: false)
      end

      if @period.pos_sessions.open.exists?
        blockers << "An open session remains on this reporting period."
      end
      if @period.pos_transactions.working.exists?
        blockers << "A working transaction remains on this reporting period."
      end
      if incomplete_sessions?
        blockers << "A session is missing closing cash snapshots."
      end

      closed = @period.pos_sessions.closed.count
      warnings << "No closed sessions are included yet." if closed.zero? && blockers.empty?

      Result.new(blockers: blockers, warnings: warnings, ready?: blockers.empty?)
    end

    private

    def incomplete_sessions?
      @period.pos_sessions.where(
        "status <> 'closed' OR closing_expected_cash_cents IS NULL OR closing_count_cents IS NULL OR closing_variance_cents IS NULL"
      ).exists?
    end
  end
end
