# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: %i[new create]
  before_action :redirect_if_signed_in, only: %i[new create]

  def new
  end

  def create
    result = Authentication::SignIn.call(
      username: params.require(:session)[:username],
      password: params.require(:session)[:password],
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    if result.success?
      start_session!(result.raw_token)
      redirect_to root_path, notice: "Signed in successfully."
    else
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    Authentication::SignOut.call(
      session: current_user_session,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
    clear_session_cookie!
    redirect_to new_session_path, notice: "Signed out."
  end

  private

  def redirect_if_signed_in
    redirect_to root_path if signed_in?
  end
end
