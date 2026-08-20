# frozen_string_literal: true

module Pos
  class XReportsController < BaseController
    def show
      @session_record = locate_x_session
      return if performed?

      unless @session_record.open?
        redirect_to pos_session_closed_path(@session_record)
        return
      end

      @register = @session_record.register
      @period = @session_record.reporting_period
      @totals = Pos::SessionTotals.for(@session_record)
      @report_groups = Pos::OperatorReport.session(totals: @totals, session: @session_record, kind: :x)
    end

    private

    def locate_x_session
      if params[:id].present?
        session_record = PosSession.find_by!(id: params[:id], store_id: current_store.id)
        authorize_x_session!(session_record)
        session_record
      else
        own = cashier_target_session
        unless own
          redirect_to pos_path, alert: "You do not have an open Session."
          return
        end
        own
      end
    end

    def authorize_x_session!(session_record)
      return if session_record.cashier_user_id == current_user.id
      return if can_view_other_sessions?

      raise ActiveRecord::RecordNotFound
    end
  end
end
