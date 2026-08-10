# frozen_string_literal: true

module Authentication
  class AdminPasswordReset
    def self.call(user:, actor:, temporary_password:)
      raise ArgumentError, "system actor cannot reset passwords" if user.system_actor?

      user.update!(
        password: temporary_password,
        password_confirmation: temporary_password,
        password_changed_at: Time.current,
        password_reset_required: true,
        locked_at: nil,
        failed_sign_in_count: 0
      )
      user.user_sessions.active.find_each { |session| session.revoke!(by: actor) }

      Audit::Recorder.record!(
        action: "authentication.admin_password_reset",
        outcome: "succeeded",
        actor_user: actor,
        actor_label: actor.display_name,
        subject: user,
        after_values: { password_reset_required: true }
      )
      user
    end
  end
end
