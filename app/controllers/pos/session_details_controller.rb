# frozen_string_literal: true

module Pos
  class SessionDetailsController < BaseController
    def show
      prepare_inquiry_shell!(surface: :session_detail)
      @session_record = find_authorized_session!
      return if performed?

      @totals = Pos::SessionTotals.for(@session_record)
      @can_view_expected = can_view_expected_for_session?(@session_record)
      @expected_cash_cents = @can_view_expected ? @totals.expected_cash_cents : nil
    end

    private

    def find_authorized_session!
      session_record = PosSession.includes(:register, :cashier_user, :reporting_period, :closed_by_user)
                                 .find_by(id: params[:id], store_id: current_store.id)
      unless session_record
        redirect_to pos_path, alert: "That session was not found."
        return
      end
      if params[:register_id].present? && session_record.register_id.to_s != params[:register_id].to_s
        redirect_to pos_path, alert: "That session was not found."
        return
      end
      unless can_view_session?(session_record)
        redirect_to pos_path, alert: "You are not authorized to view that session."
        return
      end

      session_record
    end

    def can_view_session?(session_record)
      return true if session_record.cashier_user_id == current_user.id
      return true if can_view_other_sessions?

      false
    end

    def can_view_expected_for_session?(session_record)
      return false unless can_view_expected_cash?

      can_view_session?(session_record)
    end
  end
end
