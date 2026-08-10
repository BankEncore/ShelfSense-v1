# frozen_string_literal: true

module SessionAuthentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :shelfsense_session

  included do
    helper_method :current_user, :current_user_session, :signed_in?
  end

  private

  def current_user_session
    return @current_user_session if defined?(@current_user_session)

    @current_user_session = find_current_user_session
  end

  def current_user
    current_user_session&.user
  end

  def signed_in?
    current_user.present?
  end

  def require_authentication
    return if signed_in?

    redirect_to new_session_path, alert: "Please sign in to continue."
  end

  def find_current_user_session
    token = cookies.signed[SESSION_COOKIE]
    return if token.blank?

    session_record = UserSession.find_by(token_digest: UserSession.digest(token))
    return if session_record.nil?

    unless session_record.active? && session_record.user.authenticatable?
      cookies.delete(SESSION_COOKIE)
      return
    end

    session_record.touch_last_seen!
    session_record
  end

  def start_session!(raw_token)
    cookies.signed[SESSION_COOKIE] = {
      value: raw_token,
      httponly: true,
      same_site: :lax,
      expires: UserSession::ABSOLUTE_TTL.from_now
    }
  end

  def clear_session_cookie!
    cookies.delete(SESSION_COOKIE)
  end
end
