# frozen_string_literal: true

module Pos
  class CashPaidInsController < CashActivitiesController
    before_action -> { require_cash_permission!("cash.paid_in") }

    def new
      load_reasons!
    end

    def create
      Cash::PaidIn.call(
        session: @session_record,
        actor: current_user,
        amount_cents: parse_amount!,
        reason_code: params[:reason_code],
        notes: params[:notes],
        **command_ids
      )
      redirect_to pos_path, notice: "Paid-in recorded."
    rescue Money::ParseCents::Error, Cash::Error, Pos::Denied => e
      load_reasons!
      @error = e.message
      render :new, status: :unprocessable_content
    end

    private

    def load_reasons!
      Cash::ActivityReasons.seed!
      @reasons = CashActivityReason.active.where(operation_kind: "paid_in").order(:name)
    end
  end
end
