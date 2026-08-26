# frozen_string_literal: true

module Pos
  class CashPaidOutsController < CashActivitiesController
    before_action -> { require_cash_permission!("cash.paid_out") }

    def new
      load_reasons!
    end

    def create
      Cash::PaidOut.call(
        session: @session_record,
        actor: current_user,
        amount_cents: parse_amount!,
        reason_code: params[:reason_code],
        notes: params[:notes],
        approver_username: params[:approver_username],
        approver_password: params[:approver_password],
        **command_ids
      )
      redirect_to pos_path, notice: "Paid-out recorded."
    rescue Money::ParseCents::Error, Cash::Error, Pos::Denied => e
      load_reasons!
      @error = e.message
      render :new, status: :unprocessable_content
    end

    private

    def load_reasons!
      Cash::ActivityReasons.seed!
      @reasons = CashActivityReason.active.where(operation_kind: "paid_out").order(:name)
    end
  end
end
