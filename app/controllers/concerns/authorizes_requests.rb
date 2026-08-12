# frozen_string_literal: true

module AuthorizesRequests
  extend ActiveSupport::Concern

  included do
    helper_method :current_store, :effective_permissions, :accessible_stores
  end

  private

  def current_store
    return @current_store if defined?(@current_store)

    @current_store = resolve_current_store
  end

  def accessible_stores
    return Store.none unless current_user

    @accessible_stores ||= Authorization::StoreAccess.accessible_stores_for(current_user)
  end

  def effective_permissions
    return Set.new unless current_user

    @effective_permissions ||= Authorization::PermissionEvaluator.permissions_for(
      user: current_user,
      store: current_store
    )
  end

  def authorize!(permission_key, store: current_store)
    return true if Authorization::PermissionEvaluator.allowed?(
      user: current_user,
      permission_key: permission_key,
      store: store
    )

    Audit::Recorder.record!(
      action: "authorization.denied",
      outcome: "denied",
      actor_user: current_user,
      actor_type: current_user ? "user" : "anonymous",
      actor_label: current_user&.display_name || "anonymous",
      store: store,
      reason_code: permission_key,
      metadata: { path: request.fullpath }
    )
    redirect_to root_path, alert: "You are not authorized to perform that action."
    false
  end

  def require_store_context
    return if current_store.present?

    if accessible_stores.exists?
      redirect_to new_store_selection_path
    else
      redirect_to root_path, alert: "No accessible store is available for your account."
    end
    throw :abort
  end

  def resolve_current_store
    return unless current_user

    stores = accessible_stores
    selected_id = session[:current_store_id]
    if selected_id.present?
      selected = stores.find_by(id: selected_id)
      return selected if selected
    end

    return stores.first if stores.one?

    nil
  end
end
