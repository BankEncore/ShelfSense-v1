# frozen_string_literal: true

module Authentication
  class SignOut
    def self.call(session:, ip_address: nil, user_agent: nil)
      return if session.nil? || session.revoked?

      session.revoke!
      Audit::Recorder.record!(
        action: "authentication.sign_out",
        outcome: "succeeded",
        actor_user: session.user,
        actor_label: session.user.display_name,
        user_session_id: session.id,
        subject: session.user,
        ip_address: ip_address,
        user_agent: user_agent
      )
    end
  end
end
