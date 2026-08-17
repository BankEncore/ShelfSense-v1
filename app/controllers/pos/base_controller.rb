# frozen_string_literal: true

module Pos
  class BaseController < ApplicationController
    layout "pos"

    before_action :ensure_store_context
    before_action :require_pos_transact!

    private

    def ensure_store_context
      return if current_store.present?

      if accessible_stores.exists?
        redirect_to new_store_selection_path
      else
        redirect_to root_path, alert: "No accessible store is available for your account."
      end
    end

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
  end
end
