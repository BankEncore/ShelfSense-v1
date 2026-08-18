# frozen_string_literal: true

module Pos
  class ReportingPeriodFinalizationsController < BaseController
    def create
      @period = PosReportingPeriod.find_by!(id: params[:id], store_id: current_store.id)
      Pos::Support.authorize!(current_user, @period.store)

      if @period.finalized?
        redirect_to pos_reporting_period_z_path(@period)
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

    def fail_finalize(message)
      if params[:return_to] == "closed" && params[:session_id].present?
        render_closed_summary(message)
      else
        render_enter(message)
      end
    end

    def render_closed_summary(message)
      @session_record = PosSession.find_by!(id: params[:session_id], store_id: current_store.id)
      Pos::Support.require_session_cashier!(current_user, @session_record)
      raise ActiveRecord::RecordNotFound unless @session_record.closed?

      @register = @session_record.register
      @period = @session_record.reporting_period
      @totals = Pos::SessionTotals.for(@session_record)
      flash.now[:alert] = message
      render "pos/closed_sessions/show", status: :unprocessable_content
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end

    def render_enter(message)
      @register = active_registers.find_by(id: params[:register_id]) || @period.register
      @registers = active_registers
      @gate = Pos::OpenGate.for(store: current_store, register: @register, actor: current_user)
      @opening_float = params[:opening_float]
      flash.now[:alert] = message
      render "pos/enters/show", status: :unprocessable_content
    end
  end
end
