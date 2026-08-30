# frozen_string_literal: true

module Pos
  class XReportsController < BaseController
    include Pos::ReportAccess

    skip_before_action :require_pos_transact!

    def show
      prepare_inquiry_shell!(surface: :x_report)
      @session_record = locate_x_session
      return if performed?

      unless @session_record.open?
        redirect_to pos_session_details_path(@session_record)
        return
      end

      @register = @session_record.register
      @period = @session_record.reporting_period
      @totals = Pos::SessionTotals.for(@session_record)
      @report_groups = Pos::OperatorReport.session(
        totals: @totals,
        session: @session_record,
        kind: :x,
        include_expected_cash: can_view_expected_cash?
      )
      @report_print_url = pos_report_print_path(scope: "x", id: @session_record.id)
      @tape_print_url = pos_report_print_path(scope: "x", id: @session_record.id, variant: "tape")
    end

    private

    def locate_x_session
      if params[:id].present?
        session_record = PosSession.find_by!(id: params[:id], store_id: current_store.id)
        authorize_report_session!(session_record)
        session_record
      else
        require_pos_transact!
        return if performed?

        own = cashier_target_session
        unless own
          redirect_to pos_path, alert: "You do not have an open Session."
          return
        end
        own
      end
    end
  end
end
