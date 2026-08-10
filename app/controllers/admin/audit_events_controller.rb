# frozen_string_literal: true

module Admin
  class AuditEventsController < BaseController
    before_action -> { require_permission!("audit_events.view") }

    def index
      @audit_events = filtered_scope.order(occurred_at: :desc).limit(200)
    end

    def show
      @audit_event = filtered_scope.find(params[:id])
    end

    private

    def filtered_scope
      scope = AuditEvent.all
      global_view = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "audit_events.view",
        store: nil
      )

      unless global_view
        store_ids = accessible_stores.select(:id)
        scope = scope.where(store_id: store_ids)
      end

      scope = scope.where(action: params[:action_key]) if params[:action_key].present?
      scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?
      scope = scope.where(actor_user_id: params[:actor_user_id]) if params[:actor_user_id].present?
      scope = scope.where(store_id: params[:store_id]) if params[:store_id].present? && global_view
      scope = scope.where(subject_type: params[:subject_type]) if params[:subject_type].present?
      if params[:from].present?
        scope = scope.where("occurred_at >= ?", Time.zone.parse(params[:from]))
      end
      if params[:to].present?
        scope = scope.where("occurred_at <= ?", Time.zone.parse(params[:to]))
      end
      scope
    end
  end
end
