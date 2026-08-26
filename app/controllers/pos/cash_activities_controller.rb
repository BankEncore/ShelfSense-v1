# frozen_string_literal: true

module Pos
  class CashActivitiesController < BaseController
    before_action :load_open_session!

    private

    def load_open_session!
      @session_record = cashier_target_session
      return if @session_record

      redirect_to pos_register_enter_path, alert: "Open a register before recording cash activity."
    end

    def require_cash_permission!(key)
      return if Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: key,
        store: current_store
      )

      redirect_to pos_path, alert: "You are not authorized to perform that cash action."
    end

    def parse_amount!
      parsed = Money::ParseCents.call(params[:amount])
      raise Cash::Error, "amount is required" if parsed.nil?
      raise Cash::Error, "amount must be positive" unless parsed.positive?

      parsed
    end

    def command_ids
      {
        source_id: params[:source_id].presence || SecureRandom.uuid_v7,
        idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid_v7
      }
    end
  end
end
