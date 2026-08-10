# frozen_string_literal: true

module Users
  class Deactivate
    def self.call(user:, actor:)
      raise ArgumentError, "system actor cannot be deactivated" if user.system_actor?

      Authorization::LastGlobalAdministrator.new.with_lock do
        user.update!(
          active: false,
          deactivated_at: Time.current,
          deactivated_by: actor
        )
        user.user_sessions.active.find_each { |session| session.revoke!(by: actor) }

        Audit::Recorder.record!(
          action: "users.deactivate",
          outcome: "succeeded",
          actor_user: actor,
          actor_label: actor.display_name,
          subject: user,
          after_values: { active: false }
        )
      end
      user
    end
  end
end
