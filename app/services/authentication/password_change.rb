# frozen_string_literal: true

module Authentication
  class PasswordChange
    class Error < StandardError; end

    def self.call(user:, current_password:, new_password:, new_password_confirmation:)
      raise Error, "Current password is incorrect" unless user.authenticate(current_password)

      user.update!(
        password: new_password,
        password_confirmation: new_password_confirmation,
        password_changed_at: Time.current,
        password_reset_required: false
      )
      user.user_sessions.active.find_each(&:revoke!)

      Audit::Recorder.record!(
        action: "authentication.password_change",
        outcome: "succeeded",
        actor_user: user,
        actor_label: user.display_name,
        subject: user
      )
      user
    end
  end
end
