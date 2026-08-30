# frozen_string_literal: true

module Pos
  class ReportsController < BaseController
    include Pos::ReportAccess

    def index
      prepare_inquiry_shell!(surface: :z_period)
      sessions = PosSession.closed
                           .where(store: current_store)
                           .includes(:register, :cashier_user, :reporting_period)
                           .order(closed_at: :desc)
                           .limit(100)
      @closed_sessions = sessions.select { |session| can_view_report_session?(session) }.first(50)

      periods = PosReportingPeriod.finalized
                                  .where(store: current_store)
                                  .includes(:register, :finalized_by)
                                  .order(closed_at: :desc)
                                  .limit(100)
      @z_periods = periods.select { |period| can_view_report_period?(period) }.first(50)
    end
  end
end
