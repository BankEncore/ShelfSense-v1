# frozen_string_literal: true

module Admin
  class PurchasingController < BaseController
    before_action :require_hub_access!

    def show
      @summary = Purchasing::WorkHubSummary.new(
        user: current_user,
        store: current_store,
        accessible_stores: accessible_stores
      )
    end

    private

    def require_hub_access!
      return if purchasing_hub_accessible?

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        reason_code: "purchasing.hub",
        metadata: { path: request.fullpath }
      )
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end
  end
end
