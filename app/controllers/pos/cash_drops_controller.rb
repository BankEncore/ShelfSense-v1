# frozen_string_literal: true

module Pos
  class CashDropsController < CashActivitiesController
    before_action -> { require_cash_permission!("pos.transact") }

    def new; end

    def create
      Cash::Drop.call(
        session: @session_record,
        actor: current_user,
        amount_cents: parse_amount!,
        **command_ids
      )
      redirect_to pos_path, notice: "Drop recorded."
    rescue Money::ParseCents::Error, Cash::Error, Pos::Denied => e
      @error = e.message
      render :new, status: :unprocessable_content
    end
  end
end
