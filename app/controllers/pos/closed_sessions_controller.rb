# frozen_string_literal: true

module Pos
  class ClosedSessionsController < BaseController
    def show
      @session_record = PosSession.find_by!(id: params[:id], store_id: current_store.id)
      Pos::Support.authorize!(current_user, @session_record.store)
      Pos::Support.require_session_cashier!(current_user, @session_record)
      if @session_record.open?
        redirect_to pos_session_close_path(@session_record)
        return
      end

      raise ActiveRecord::RecordNotFound unless @session_record.closed?

      @register = @session_record.register
      @period = @session_record.reporting_period
      @totals = Pos::SessionTotals.for(@session_record)
      session[:pos_register_id] = @register.id
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    end
  end
end
