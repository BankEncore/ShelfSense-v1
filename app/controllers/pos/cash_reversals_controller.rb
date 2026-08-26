# frozen_string_literal: true

module Pos
  class CashReversalsController < CashActivitiesController
    skip_before_action :load_open_session!
    before_action -> { require_cash_permission!("cash.reverse") }

    def new
      load_form!
    end

    def create
      operation = CashOperation.find(params.require(:cash_operation_id))
      raise Cash::Error, "operation is not in this store" unless operation.store_id == current_store.id

      Cash::Reverse.call(
        operation: operation,
        actor: current_user,
        reason_code: params[:reason_code],
        notes: params[:notes],
        **command_ids
      )
      redirect_to pos_path, notice: "Cash operation reversed."
    rescue Cash::Error, Pos::Denied, ActiveRecord::RecordNotFound => e
      load_form!
      @error = e.message
      render :new, status: :unprocessable_content
    end

    private

    def load_form!
      Cash::ActivityReasons.seed!
      @reasons = CashActivityReason.active.where(operation_kind: "reverse").order(:name)
      open_ids = PosSession.open.where(store: current_store).select(:id)
      @operations = CashOperation.where(store: current_store, pos_session_id: open_ids)
                                 .where.not(operation_type: %w[initialize_safe reconcile reverse])
                                 .order(occurred_at: :desc)
                                 .select { |operation| Cash::Reverse.reversible?(operation) }
    end
  end
end
