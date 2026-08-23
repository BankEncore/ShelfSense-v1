# frozen_string_literal: true

module AdminNavigationHelper
  def admin_navigation
    return unless current_user

    @admin_navigation ||= Admin::NavigationViewModel.new(
      user: current_user,
      permissions: effective_permissions,
      current_store: current_store,
      accessible_stores: accessible_stores,
      controller_path: controller.controller_path,
      hub_visible: purchasing_hub_accessible?
    )
  end
end
