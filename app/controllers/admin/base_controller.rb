# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    private

    def require_permission!(key)
      return if Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: key,
        store: current_store
      )

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        reason_code: key,
        metadata: { path: request.fullpath }
      )
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end

    def rescue_stale
      yield
    rescue ActiveRecord::StaleObjectError
      redirect_back fallback_location: root_path, alert: "This record was changed by someone else. Reload and try again."
    end
  end
end
