# frozen_string_literal: true

module Admin
  class RolesController < BaseController
    before_action -> { require_permission!("roles.view") }, only: %i[index show]
    before_action -> { require_permission!("roles.create") }, only: %i[new create]
    before_action -> { require_permission!("roles.manage") }, only: %i[edit update]
    before_action -> { require_permission!("roles.deactivate") }, only: :destroy
    before_action :set_role, only: %i[show edit update destroy]

    def index
      @roles = Role.order(:name)
    end

    def show; end

    def new
      @role = Role.new(assignment_scope: "store")
      @permissions = Permission.active.order(:group_key, :key)
    end

    def create
      @role = Role.new(role_params.merge(system_role: false))
      if @role.save
        sync_permissions!(@role)
        Audit::Recorder.record!(
          action: "roles.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          subject: @role,
          after_values: { key: @role.key, name: @role.name }
        )
        redirect_to admin_role_path(@role), notice: "Role created."
      else
        @permissions = Permission.active.order(:group_key, :key)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @permissions = Permission.active.order(:group_key, :key)
    end

    def update
      rescue_stale do
        if @role.system_role?
          redirect_to admin_role_path(@role), alert: "System roles are managed by application seeds."
          return
        end

        if @role.update(role_params)
          sync_permissions!(@role)
          Audit::Recorder.record!(
            action: "roles.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            subject: @role
          )
          redirect_to admin_role_path(@role), notice: "Role updated."
        else
          @permissions = Permission.active.order(:group_key, :key)
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      if @role.system_role?
        redirect_to admin_role_path(@role), alert: "System roles cannot be deactivated here."
        return
      end

      @role.update!(active: false, deactivated_at: Time.current, deactivated_by: current_user)
      Audit::Recorder.record!(
        action: "roles.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        subject: @role
      )
      redirect_to admin_roles_path, notice: "Role deactivated."
    end

    private

    def set_role
      @role = Role.find(params[:id])
    end

    def role_params
      params.require(:role).permit(:key, :name, :description, :assignment_scope, :lock_version)
    end

    def sync_permissions!(role)
      selected = Array(params.dig(:role, :permission_ids)).reject(&:blank?)
      desired = Permission.where(id: selected)
      current_ids = role.permission_ids
      (desired.map(&:id) - current_ids).each do |permission_id|
        role.role_permissions.create!(permission_id: permission_id, granted_by: current_user)
      end
      role.role_permissions.where.not(permission_id: desired.map(&:id)).find_each(&:destroy!)
    end
  end
end
