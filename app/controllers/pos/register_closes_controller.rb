# frozen_string_literal: true

module Pos
  class RegisterClosesController < BaseController
    def create
      @register = find_register
      unless @register
        redirect_to pos_register_enter_path
        return
      end

      session_record = actor_open_session(@register)
      unless session_record
        redirect_to pos_register_enter_path(register_id: @register.id)
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
    rescue Pos::Denied
      raise ActiveRecord::RecordNotFound
    rescue Pos::StaleObject, Pos::Error => e
      redirect_to pos_register_workspace_path, alert: e.message
    end

    private

    def actor_open_session(register)
      PosSession.open.find_by(store: current_store, register: register, cashier_user: current_user)
    end

    def nonempty_working?(transaction)
      transaction.pos_transaction_lines.exists? || transaction.pos_tenders.exists?
    end
  end
end
