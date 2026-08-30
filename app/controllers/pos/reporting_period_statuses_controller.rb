# frozen_string_literal: true

module Pos
  class ReportingPeriodStatusesController < BaseController
    def show
      prepare_inquiry_shell!(surface: :z_period)
      @period = locate_period!
      return if performed?

      if @period.finalized?
        redirect_to pos_reporting_period_z_path(@period)
        return
      end

      @register = @period.register
      @totals = Pos::PeriodTotals.for(@period)
      @report_groups = Pos::OperatorReport.period(
        period: @period,
        include_expected_cash: can_view_expected_cash?
      )
      @finalize = Pos::ReportingPeriodFinalizeBlockers.call(period: @period)
    end

    private

    def locate_period!
      if params[:id].present?
        period = PosReportingPeriod.find_by(id: params[:id], store_id: current_store.id)
        raise ActiveRecord::RecordNotFound unless period

        Pos::Support.authorize!(current_user, period.store)
        period
      else
        resolved = Pos::ReportingSurfaceResolver.call(
          store: current_store,
          actor: current_user,
          state: @state,
          reporting_period_id: params[:reporting_period_id],
          register_id_param: params[:register_id]
        )
        case resolved.status
        when :ok
          resolved.period
        when :chooser
          @candidate_periods = resolved.candidate_periods
          @candidate_sessions = resolved.candidate_sessions
          render :chooser
          nil
        else
          redirect_to pos_path, alert: period_denied_message(resolved.denied_reason)
          nil
        end
      end
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end

    def period_denied_message(reason)
      case reason
      when "register_required"
        "Select a Register before viewing Z status."
      when "sessions_view_required"
        "You are not authorized to view that reporting period."
      else
        "That reporting period was not found."
      end
    end
  end
end
