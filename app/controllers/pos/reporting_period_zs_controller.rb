# frozen_string_literal: true

module Pos
  class ReportingPeriodZsController < BaseController
    def show
      @period = PosReportingPeriod.find_by!(id: params[:id], store_id: current_store.id)
      Pos::Support.authorize!(current_user, @period.store)
      raise ActiveRecord::RecordNotFound unless @period.finalized?

      @register = @period.register
      @report_groups = Pos::OperatorReport.period(period: @period)
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end
  end
end
