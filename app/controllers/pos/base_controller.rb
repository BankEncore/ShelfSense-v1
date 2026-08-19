# frozen_string_literal: true

module Pos
  class BaseController < ApplicationController
    layout "pos"

    before_action :require_store_context
    before_action :require_pos_transact!

    helper_method :pos_resume_register_path

    private

    def require_pos_transact!
      return if Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "pos.transact",
        store: current_store
      )

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        reason_code: "pos.transact",
        metadata: { path: request.fullpath }
      )
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end

    def active_registers
      current_store.registers.active.order(:register_number)
    end

    def find_register
      register_id = params[:register_id].presence || session[:pos_register_id]
      active_registers.find_by(id: register_id)
    end

    def cashier_target_session
      bound_cashier_open_session || sole_cashier_open_session
    end

    def pos_resume_register_path
      resume_session = cashier_target_session
      if resume_session
        pos_register_workspace_path(register_id: resume_session.register_id)
      else
        pos_register_enter_path
      end
    end

    def cashier_open_sessions
      PosSession.open.where(store: current_store, cashier_user: current_user)
    end

    def bound_cashier_open_session
      register_id = session[:pos_register_id]
      return if register_id.blank?

      cashier_open_sessions.find_by(register_id: register_id)
    end

    def sole_cashier_open_session
      sessions = cashier_open_sessions.limit(2).to_a
      sessions.first if sessions.size == 1
    end
  end
end
