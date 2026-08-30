# frozen_string_literal: true

module Pos
  # Server-authorized printable report/tape fragments. Rebuilds P13 under current permissions.
  class ReportPrintsController < BaseController
    include Pos::ReportAccess

    layout false

    def show
      case params[:scope].to_s
      when "session"
        prepare_session_print!
      when "x"
        prepare_x_print!
      when "period"
        prepare_period_print!
      else
        raise ActiveRecord::RecordNotFound
      end

      @variant = params[:variant].to_s == "tape" ? :tape : :report
      @reprint = params[:reprint].present?
      render :show
    end

    private

    def prepare_session_print!
      @session_record = PosSession.includes(:register, :cashier_user, :reporting_period, :closed_by_user)
                                  .find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless @session_record
      authorize_report_session!(@session_record)
      raise ActiveRecord::RecordNotFound unless @session_record.closed?

      @register = @session_record.register
      @period = @session_record.reporting_period
      @include_expected_cash = can_view_expected_cash?
      @report_groups = Pos::OperatorReport.session(
        totals: Pos::SessionTotals.for(@session_record),
        session: @session_record,
        kind: :session,
        include_expected_cash: @include_expected_cash
      )
      @tape_identity = Pos::ShiftEndTapeIdentity.for_session(
        session: @session_record,
        store: current_store,
        reprint: params[:reprint].present?
      )
      @print_title = "Closed Session Report"
      @print_banners = []
      @print_meta = session_meta
    end

    def prepare_x_print!
      @session_record = if params[:id].present?
        PosSession.find_by(id: params[:id], store_id: current_store.id)
      else
        cashier_target_session
      end
      raise ActiveRecord::RecordNotFound unless @session_record
      authorize_report_session!(@session_record)
      raise ActiveRecord::RecordNotFound unless @session_record.open?

      @register = @session_record.register
      @period = @session_record.reporting_period
      @include_expected_cash = can_view_expected_cash?
      @report_groups = Pos::OperatorReport.session(
        totals: Pos::SessionTotals.for(@session_record),
        session: @session_record,
        kind: :x,
        include_expected_cash: @include_expected_cash
      )
      @tape_identity = Pos::ShiftEndTapeIdentity.for_session(
        session: @session_record,
        store: current_store,
        reprint: params[:reprint].present?
      )
      @print_title = "X Report"
      @print_banners = [ "X REPORT", "INTERIM — SESSION REMAINS OPEN" ]
      @print_meta = session_meta
    end

    def prepare_period_print!
      @period = PosReportingPeriod.find_by(id: params[:id], store_id: current_store.id)
      raise ActiveRecord::RecordNotFound unless @period
      authorize_report_period!(@period)

      @register = @period.register
      @include_expected_cash = can_view_expected_cash?
      @report_groups = Pos::OperatorReport.period(
        period: @period,
        include_expected_cash: @include_expected_cash
      )
      @tape_identity = Pos::ShiftEndTapeIdentity.for_period(
        period: @period,
        store: current_store,
        reprint: params[:reprint].present?
      )
      if @period.finalized?
        @print_title = "Z report"
        @print_banners = []
        @print_meta = [
          "Store  #{current_store.admin_label}",
          "Register  #{@register.admin_label}",
          "Business date  #{@period.business_date.iso8601}",
          "Finalized  #{Pos::ShiftEndTapeIdentity.format_timestamp(@period.closed_at, current_store)}",
          "Finalized by  #{@period.finalized_by.display_name}"
        ]
      else
        @print_title = "Z Period Status"
        @print_banners = [ "CURRENT Z — PERIOD REMAINS OPEN" ]
        @print_meta = [
          "Store  #{current_store.admin_label}",
          "Register  #{@register.admin_label}",
          "Business date  #{@period.business_date.iso8601}"
        ]
      end
    end

    def session_meta
      [
        "Store  #{current_store.admin_label}",
        "Register  #{@register.admin_label}",
        "Cashier  #{@session_record.cashier_user.display_name}",
        "Business date  #{@period.business_date.iso8601}"
      ]
    end
  end
end
