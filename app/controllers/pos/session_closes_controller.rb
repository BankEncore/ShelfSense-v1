# frozen_string_literal: true

module Pos
  class SessionClosesController < BaseController
    before_action :load_session!

    def show
      return if performed?

      if @session_record.closed?
        redirect_to pos_session_closed_path(@session_record)
        return
      end

      if @session_record.pos_transactions.working.exists?
        redirect_to pos_register_workspace_path, alert: "Complete or cancel the current sale before closing."
        return
      end

      @closing_count = params[:closing_count]
    end

    def create
      return if performed?

      if @session_record.closed?
        redirect_to pos_session_closed_path(@session_record)
        return
      end

      count_cents = parse_closing_count
      Pos::CloseSession.call(
        session: @session_record,
        actor: current_user,
        expected_lock_version: params.require(:expected_lock_version),
        closing_count_cents: count_cents
      )
      redirect_to pos_session_closed_path(@session_record)
    rescue ActionController::ParameterMissing
      recover_blind("expected lock version is required")
    rescue Money::ParseCents::Error => e
      recover_blind(e.message)
    rescue Pos::Error => e
      recover_blind(e.message)
    rescue Pos::StaleObject
      recover_blind("This session was changed. Reload and try again.")
    end

    def resume_sales
      return if performed?

      if @session_record.closed?
        redirect_to pos_session_closed_path(@session_record)
        return
      end

      Pos::ResumeOrStartTransaction.call(session: @session_record, actor: current_user)
      redirect_to pos_register_workspace_path
    rescue Pos::Denied, Pos::Error => e
      redirect_to pos_register_enter_path(register_id: @session_record.register_id), alert: e.message
    end

    private

    def load_session!
      @session_record = PosSession.find_by!(id: params[:id], store_id: current_store.id)
      Pos::Support.authorize!(current_user, @session_record.store)
      Pos::Support.require_session_cashier!(current_user, @session_record)
      @register = @session_record.register
      session[:pos_register_id] = @register.id
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end

    def parse_closing_count
      parsed = Money::ParseCents.call(params[:closing_count])
      raise Pos::Error, "closing count is required" if parsed.nil?
      raise Pos::Error, "closing count must be a non-negative amount" if parsed.negative?

      parsed
    end

    def recover_blind(message)
      @session_record.reload

      if @session_record.closed?
        redirect_to pos_session_closed_path(@session_record)
      elsif @session_record.pos_transactions.working.exists?
        redirect_to pos_register_workspace_path, alert: "Complete or cancel the current sale before closing."
      else
        @closing_count = params[:closing_count]
        @feedback = message
        render :show, status: :unprocessable_content
      end
    end
  end
end
