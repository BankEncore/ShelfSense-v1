# frozen_string_literal: true

module Pos
  class ReportingPeriodFinalizationsController < BaseController
    def new
      prepare_inquiry_shell!(surface: :z_period)
      @period = load_period!
      return if performed?

      if @period.finalized?
        redirect_to pos_reporting_period_z_path(@period)
        return
      end

      @register = @period.register
      @finalize = Pos::ReportingPeriodFinalizeBlockers.call(period: @period)
      @report_groups = Pos::OperatorReport.period(
        period: @period,
        include_expected_cash: can_view_expected_cash?
      )
    end

    def create
      @period = PosReportingPeriod.find_by!(id: params[:id], store_id: current_store.id)
      Pos::Support.authorize!(current_user, @period.store)

      if @period.finalized?
        redirect_to pos_reporting_period_z_path(@period)
        return
      end

      readiness = Pos::ReportingPeriodFinalizeBlockers.call(period: @period)
      unless readiness.ready?
        fail_finalize(readiness.blockers.first || "Cannot finalize this reporting period.")
        return
      end

      Pos::FinalizeReportingPeriod.call(
        period: @period,
        actor: current_user,
        expected_lock_version: params.require(:expected_lock_version)
      )
      redirect_to pos_reporting_period_z_path(@period)
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    rescue ActionController::ParameterMissing
      fail_finalize("expected lock version is required")
    rescue Pos::StaleObject
      @period.reload
      if @period.finalized?
        redirect_to pos_reporting_period_z_path(@period)
      else
        fail_finalize("This reporting period was changed. Reload and try again.")
      end
    rescue Pos::Error => e
      fail_finalize(e.message)
    end

    private

    def load_period!
      period = PosReportingPeriod.find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless period

      Pos::Support.authorize!(current_user, period.store)
      period
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end

    def fail_finalize(message)
      if params[:session_id].present? && %w[closed session_details].include?(params[:return_to].to_s)
        render_session_details_summary(message)
      elsif params[:return_to].to_s == "confirm" || request.referer.to_s.include?("/finalize")
        render_confirm(message)
      else
        render_enter(message)
      end
    end

    def render_confirm(message)
      prepare_inquiry_shell!(surface: :z_period)
      @period = @period.reload
      @register = @period.register
      @finalize = Pos::ReportingPeriodFinalizeBlockers.call(period: @period)
      @report_groups = Pos::OperatorReport.period(
        period: @period,
        include_expected_cash: can_view_expected_cash?
      )
      flash.now[:alert] = message
      render :new, status: :unprocessable_content
    end

    def render_session_details_summary(message)
      @session_record = PosSession.find_by!(id: params[:session_id], store_id: current_store.id)
      Pos::Support.require_session_cashier!(current_user, @session_record)
      raise ActiveRecord::RecordNotFound unless @session_record.closed?

      @register = @session_record.register
      @period = @session_record.reporting_period
      @totals = Pos::SessionTotals.for(@session_record)
      @can_view_expected = can_view_expected_cash?
      @expected_cash_cents = @can_view_expected ? @totals.expected_cash_cents : nil
      @report_groups = Pos::OperatorReport.session(
        totals: @totals,
        session: @session_record,
        kind: :session,
        include_expected_cash: @can_view_expected
      )
      prepare_inquiry_shell!(surface: :session_detail)
      flash.now[:alert] = message
      render "pos/session_details/show", status: :unprocessable_content
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end

    def render_enter(message)
      @opening_float = params[:opening_float]
      flash.now[:alert] = message
      register = active_registers.find_by(id: params[:register_id]) || @period.register
      prepare_register_shell!(resolve_register_state(requested_register: register))
      render "pos/homes/show", status: :unprocessable_content
    end
  end
end
