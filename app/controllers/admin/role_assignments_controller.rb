# frozen_string_literal: true

module Admin
  class RoleAssignmentsController < BaseController
    before_action -> { require_permission!("users.assign_roles") }

    def index
      @role_assignments = RoleAssignment.includes(:user, :role, :store).order(created_at: :desc)
    end

    def new
      @role_assignment = RoleAssignment.new
      @users = User.human.active.order(:username)
      @roles = Role.active.order(:name)
      @stores = Store.active.order(:name)
    end

    def create
      @role_assignment = RoleAssignment.new(assignment_params.merge(assigned_by: current_user, effective_at: Time.current))
      begin
        Authorization::LastGlobalAdministrator.new.with_lock do
          @role_assignment.save!
          Audit::Recorder.record!(
            action: "role_assignments.create",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: @role_assignment.store,
            subject: @role_assignment,
            after_values: {
              user_id: @role_assignment.user_id,
              role_id: @role_assignment.role_id,
              store_id: @role_assignment.store_id
            }
          )
        end
        redirect_to admin_role_assignments_path, notice: "Role assigned."
      rescue ActiveRecord::RecordInvalid
        @users = User.human.active.order(:username)
        @roles = Role.active.order(:name)
        @stores = Store.active.order(:name)
        render :new, status: :unprocessable_entity
      rescue Authorization::LastGlobalAdministrator::WouldRemoveLastAdministrator => e
        redirect_to admin_role_assignments_path, alert: e.message
      end
    end

    def destroy
      assignment = RoleAssignment.find(params[:id])
      Authorization::LastGlobalAdministrator.new.with_lock do
        assignment.update!(
          revoked_at: Time.current,
          revoked_by: current_user,
          revocation_reason: params[:revocation_reason].presence || "revoked"
        )
        Audit::Recorder.record!(
          action: "role_assignments.revoke",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: assignment.store,
          subject: assignment
        )
      end
      redirect_to admin_role_assignments_path, notice: "Role assignment revoked."
    rescue Authorization::LastGlobalAdministrator::WouldRemoveLastAdministrator => e
      redirect_to admin_role_assignments_path, alert: e.message
    end

    private

    def assignment_params
      params.require(:role_assignment).permit(:user_id, :role_id, :store_id).tap do |attrs|
        attrs[:store_id] = attrs[:store_id].presence
      end
    end
  end
end
