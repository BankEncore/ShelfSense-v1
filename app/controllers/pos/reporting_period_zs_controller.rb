# frozen_string_literal: true

module Pos
  class ReportingPeriodZsController < BaseController
    def show
      prepare_inquiry_shell!(surface: :z_period)
      @period = PosReportingPeriod.find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless @period

      Pos::Support.authorize!(current_user, @period.store)
      raise ActiveRecord::RecordNotFound unless @period.finalized?

      @register = @period.register
      @report_groups = Pos::OperatorReport.period(
        period: @period,
        include_expected_cash: can_view_expected_cash?
      )
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end
  end
end
