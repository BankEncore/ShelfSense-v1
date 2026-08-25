# frozen_string_literal: true

module Admin
  # Disposable UDS-5.0 compact-navigation prototype. Signed-in only; no extra
  # permission so Profile B can exercise the live catalog. Retire in UDS-5.2 or 5.5.
  class Uds5NavigationPrototypesController < BaseController
    VARIANTS = %w[expanded disclosures area_row].freeze
    DEFAULT_AS_CONTROLLER = "admin/products"

    def show
      @variant = VARIANTS.include?(params[:variant].to_s) ? params[:variant].to_s : "expanded"
      @as_controller = params.key?(:as_controller) ? params[:as_controller].to_s : DEFAULT_AS_CONTROLLER
      @prototype_nav = Admin::NavigationViewModel.new(
        user: current_user,
        permissions: effective_permissions,
        current_store: current_store,
        accessible_stores: accessible_stores,
        controller_path: @as_controller,
        hub_visible: purchasing_hub_accessible?
      )
    end
  end
end
