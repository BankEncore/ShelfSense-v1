# frozen_string_literal: true

module Pos
  class RegisterClosesController < BaseController
    def create
      @register = find_register
      unless @register
        redirect_to pos_register_enter_path
        return
      end

      session_record = PosSession.find_by!(
        id: params.require(:session_id),
        store_id: current_store.id,
        register: @register,
        cashier_user: current_user
      )

      if session_record.closed?
        redirect_to pos_session_closed_path(session_record)
        return
      end

      working = session_record.pos_transactions.working.first
      if working
        if nonempty_working?(working)
          redirect_to pos_register_workspace_path, alert: "Complete or cancel the current sale before closing."
          return
        end

        Pos::CancelTransaction.call(
          transaction: working,
          actor: current_user,
          expected_lock_version: working.lock_version
        )
      end

      redirect_to pos_session_close_path(session_record)
    rescue ActionController::ParameterMissing
      raise ActiveRecord::RecordNotFound
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    rescue Pos::StaleObject, Pos::Error => e
      redirect_to pos_register_workspace_path, alert: e.message
    end

    private

    def nonempty_working?(transaction)
      transaction.pos_transaction_lines.exists? || transaction.pos_tenders.exists?
    end
  end
end
