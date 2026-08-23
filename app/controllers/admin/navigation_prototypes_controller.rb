# frozen_string_literal: true

module Admin
  class NavigationPrototypesController < BaseController
    before_action :require_prototype_access!

    def show
      @nav = Admin::NavigationViewModel.new(
        user: current_user,
        permissions: effective_permissions,
        current_store: current_store,
        accessible_stores: accessible_stores,
        controller_path: params[:as_controller].presence || "admin/navigation_prototypes"
      )
      @demo_controller_path = params[:as_controller].presence
    end

    private

    def require_prototype_access!
      preview = Admin::NavigationViewModel.new(
        user: current_user,
        permissions: effective_permissions,
        current_store: current_store,
        accessible_stores: accessible_stores,
        controller_path: "admin/navigation_prototypes"
      )
      return if preview.any_destination_visible?

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        reason_code: "navigation.prototype",
        metadata: { path: request.fullpath }
      )
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end
  end
end
