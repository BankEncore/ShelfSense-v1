# frozen_string_literal: true

module Pos
  class SessionDetailsController < BaseController
    include Pos::ReportAccess

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
      @report_print_url = pos_report_print_path(scope: "session", id: @session_record.id)
      @tape_print_url = pos_report_print_path(scope: "session", id: @session_record.id, variant: "tape")
    end

    private

    def find_authorized_session!
      session_record = PosSession.includes(:register, :cashier_user, :reporting_period, :closed_by_user)
                                 .find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless session_record

      if params[:register_id].present? && session_record.register_id.to_s != params[:register_id].to_s
        raise ActiveRecord::RecordNotFound
      end
      unless can_view_report_session?(session_record)
        redirect_to pos_path, alert: "You are not authorized to view that session."
        return
      end

      session_record
    end

    def can_view_expected_for_session?(session_record)
      return false unless can_view_expected_cash?

      can_view_report_session?(session_record)
    end
  end
end
