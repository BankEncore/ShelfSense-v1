# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action -> { require_permission!("users.view") }, only: %i[index show]
    before_action -> { require_permission!("users.create") }, only: %i[new create]
    before_action -> { require_permission!("users.manage") }, only: %i[edit update]
    before_action -> { require_permission!("users.deactivate") }, only: :deactivate
    before_action -> { require_permission!("users.manage") }, only: :reset_password
    before_action :set_user, only: %i[show edit update deactivate reset_password]

    def index
      @users = User.human.order(:username)
    end

    def show; end

    def new
      @user = User.new(actor_type: "human")
    end

    def create
      @user = User.new(user_params.merge(actor_type: "human"))
      if @user.save
        Audit::Recorder.record!(
          action: "users.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          subject: @user,
          after_values: { username: @user.username }
        )
        redirect_to admin_user_path(@user), notice: "User created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        attrs = user_params
        attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?
        if @user.update(attrs)
          Audit::Recorder.record!(
            action: "users.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            subject: @user,
            after_values: { username: @user.username, display_name: @user.display_name }
          )
          redirect_to admin_user_path(@user), notice: "User updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def deactivate
      Users::Deactivate.call(user: @user, actor: current_user)
      redirect_to admin_users_path, notice: "User deactivated."
    rescue Authorization::LastGlobalAdministrator::WouldRemoveLastAdministrator => e
      redirect_to admin_user_path(@user), alert: e.message
    end

    def reset_password
      temporary = SecureRandom.base58(16)
      Authentication::AdminPasswordReset.call(user: @user, actor: current_user, temporary_password: temporary)
      redirect_to admin_user_path(@user), notice: "Temporary password: #{temporary}"
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(
        :username, :email, :display_name, :password, :password_confirmation, :lock_version
      )
    end
  end
end
