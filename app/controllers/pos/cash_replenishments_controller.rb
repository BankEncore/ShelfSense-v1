# frozen_string_literal: true

module Pos
  class CashReplenishmentsController < CashActivitiesController
    before_action -> { require_cash_permission!("cash.move") }

    def new
      load_sessions!
    end

    def create
      load_sessions!
      Cash::Replenish.call(
        session: @session_record,
        actor: current_user,
        amount_cents: parse_amount!,
        **command_ids
      )
      redirect_to pos_path, notice: "Replenishment recorded."
    rescue Money::ParseCents::Error, Cash::Error, Pos::Denied => e
      load_sessions!
      @error = e.message
      render :new, status: :unprocessable_content
    end

    private

    def load_open_session!
      load_sessions!
      return if @session_record

      redirect_to pos_path, alert: "No open register session is available to replenish."
    end

    def load_sessions!
      @open_sessions = PosSession.open.where(store: current_store).includes(:register, :cashier_user).order(:opened_at)
      @session_record = if params[:pos_session_id].present?
        @open_sessions.find_by(id: params[:pos_session_id])
      else
        cashier_target_session || @open_sessions.first
      end
    end
  end
end
