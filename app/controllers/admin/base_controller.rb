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

    def create_and_audit!(record, action:, after_values: nil)
      record.class.transaction do
        return false unless record.save

        Audit::Recorder.record!(
          action: action,
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: record,
          after_values: after_values
        )
      end
      true
    end

    def save_and_audit!(record, attrs:, action:, before_keys:)
      record.class.transaction do
        before = record.attributes.slice(*before_keys)
        return false unless record.update(attrs)

        Audit::Recorder.record!(
          action: action,
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: record,
          before_values: before,
          after_values: record.attributes.slice(*before.keys)
        )
      end
      true
    end

    def mutate_and_audit!(record, action:, before_values: nil, after_values: nil)
      record.class.transaction do
        yield
        Audit::Recorder.record!(
          action: action,
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: record,
          before_values: before_values,
          after_values: after_values
        )
      end
    end

    def reactivate_configuration!(record, permission_key:, audit_action:, redirect_path:)
      rescue_stale do
        Configuration::Reactivate.call(
          record: record,
          actor: current_user,
          store: current_store,
          lock_version: params.dig(record.model_name.param_key, :lock_version) || params[:lock_version],
          audit_action: audit_action
        )
        redirect_to redirect_path, notice: "#{record.class.model_name.human} reactivated."
      rescue Configuration::Reactivate::Error => e
        redirect_to redirect_path, alert: e.message
      end
    end
  end
end
