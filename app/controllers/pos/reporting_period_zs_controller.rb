# frozen_string_literal: true

module Pos
  class ReportingPeriodZsController < BaseController
    include Pos::ReportAccess

    def show
      prepare_inquiry_shell!(surface: :z_period)
      @period = PosReportingPeriod.find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless @period
      authorize_report_period!(@period)
      raise ActiveRecord::RecordNotFound unless @period.finalized?

      @register = @period.register
      @report_groups = Pos::OperatorReport.period(
        period: @period,
        include_expected_cash: can_view_expected_cash?
      )
      @report_print_url = pos_report_print_path(scope: "period", id: @period.id)
      @tape_print_url = pos_report_print_path(scope: "period", id: @period.id, variant: "tape")
    end
  end
end
