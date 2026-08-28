# frozen_string_literal: true

module Pos
  class XReportsController < BaseController
    skip_before_action :require_pos_transact!

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
      @report_groups = Pos::OperatorReport.session(
        totals: @totals,
        session: @session_record,
        kind: :x,
        include_expected_cash: can_view_expected_cash?
      )
    end

    private

    def locate_x_session
      if params[:id].present?
        session_record = PosSession.find_by!(id: params[:id], store_id: current_store.id)
        authorize_x_session!(session_record)
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

    def authorize_x_session!(session_record)
      return if session_record.cashier_user_id == current_user.id && transact_allowed?
      return if can_view_other_sessions?

      raise ActiveRecord::RecordNotFound
    end

    def transact_allowed?
      Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "pos.transact",
        store: current_store
      )
    end
  end
end
