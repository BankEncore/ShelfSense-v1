# frozen_string_literal: true

module Pos
  class SessionDetailsController < BaseController
    def show
      prepare_inquiry_shell!(surface: :session_detail)
      @session_record = find_authorized_session!
      return if performed?

      @register = @session_record.register
      @period = @session_record.reporting_period
      @totals = Pos::SessionTotals.for(@session_record)
      @can_view_expected = can_view_expected_for_session?(@session_record)
      @expected_cash_cents = @can_view_expected ? @totals.expected_cash_cents : nil

      return unless @session_record.closed?

      @report_groups = Pos::OperatorReport.session(
        totals: @totals,
        session: @session_record,
        kind: :session,
        include_expected_cash: @can_view_expected
      )
    end

    private

    def find_authorized_session!
      session_record = PosSession.includes(:register, :cashier_user, :reporting_period, :closed_by_user)
                                 .find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless session_record

      if params[:register_id].present? && session_record.register_id.to_s != params[:register_id].to_s
        raise ActiveRecord::RecordNotFound
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
      # Closed-session report was historically store-authorized (retired closed_sessions).
      return true if session_record.closed? && store_pos_authorized?

      false
    end

    def store_pos_authorized?
      Pos::Support.authorize!(current_user, current_store)
      true
    rescue Pos::Denied
      false
    end

    def can_view_expected_for_session?(session_record)
      return false unless can_view_expected_cash?

      can_view_session?(session_record)
    end
  end
end
