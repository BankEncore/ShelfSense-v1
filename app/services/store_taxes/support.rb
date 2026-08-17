# frozen_string_literal: true

module StoreTaxes
  module Support
    module_function

    def authorize!(actor, store, permission_key)
      return if Authorization::PermissionEvaluator.allowed?(
        user: actor,
        permission_key: permission_key,
        store: store
      )

      Audit::Recorder.record!(
        action: "authorization.denied",
        outcome: "denied",
        actor_user: actor,
        actor_label: actor.display_name,
        store: store,
        reason_code: permission_key
      )
      raise StoreTaxes::Denied, "not authorized to #{permission_key} for this store"
    end
  end
end
