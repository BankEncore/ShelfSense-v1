# frozen_string_literal: true

module Authentication
  class SignIn
    MAX_FAILED_ATTEMPTS = 5

    Result = Struct.new(:success?, :user, :session, :raw_token, :error, keyword_init: true)

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(username:, password:, ip_address: nil, user_agent: nil)
      @username = username.to_s.strip
      @password = password
      @ip_address = ip_address
      @user_agent = user_agent
    end

    def call
      user = User.find_by("lower(username) = ?", @username.downcase)

      if user.nil?
        return failure("Invalid username or password")
      end

      if user.system_actor? || !user.interactive?
        audit_failure(user, "non_interactive_actor")
        return failure("Invalid username or password")
      end

      if !user.active? || user.locked_at.present?
        audit_failure(user, "inactive_or_locked")
        return failure("Invalid username or password")
      end

      unless user.authenticate(@password)
        register_failed_attempt!(user)
        audit_failure(user, "invalid_password")
        return failure("Invalid username or password")
      end

      user.update!(failed_sign_in_count: 0, last_signed_in_at: Time.current)
      session, raw_token = UserSession.issue!(user: user, ip_address: @ip_address, user_agent: @user_agent)

      Audit::Recorder.record!(
        action: "authentication.sign_in",
        outcome: "succeeded",
        actor_user: user,
        actor_label: user.display_name,
        user_session_id: session.id,
        subject: user,
        ip_address: @ip_address,
        user_agent: @user_agent
      )

      Result.new(success?: true, user: user, session: session, raw_token: raw_token)
    end

    private

    def failure(message)
      Result.new(success?: false, error: message)
    end

    def register_failed_attempt!(user)
      attrs = { failed_sign_in_count: user.failed_sign_in_count + 1 }
      attrs[:locked_at] = Time.current if attrs[:failed_sign_in_count] >= MAX_FAILED_ATTEMPTS
      user.update!(attrs)
    end

    def audit_failure(user, reason_code)
      Audit::Recorder.record!(
        action: "authentication.sign_in",
        outcome: "failed",
        actor_user: user,
        actor_label: user.display_name,
        subject: user,
        reason_code: reason_code,
        ip_address: @ip_address,
        user_agent: @user_agent
      )
    end
  end
end
