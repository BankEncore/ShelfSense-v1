# frozen_string_literal: true

module Pos
  class ReportsController < BaseController
    def index
      prepare_inquiry_shell!(surface: :z_period)
      @closed_sessions = PosSession.closed
                                   .where(store: current_store)
                                   .includes(:register, :cashier_user, :reporting_period)
                                   .order(closed_at: :desc)
                                   .limit(50)
      @z_periods = PosReportingPeriod.finalized
                                     .where(store: current_store)
                                     .includes(:register, :finalized_by)
                                     .order(closed_at: :desc)
                                     .limit(50)
    end
  end
end
