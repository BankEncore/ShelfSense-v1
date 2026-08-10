# frozen_string_literal: true

module Admin
  class WorkstationsController < BaseController
    before_action -> { require_permission!("workstations.view") }, only: %i[index show]
    before_action -> { require_permission!("workstations.create") }, only: %i[new create]
    before_action -> { require_permission!("workstations.manage") }, only: %i[edit update]
    before_action -> { require_permission!("workstations.deactivate") }, only: :destroy
    before_action :require_store_context, except: %i[index show]
    before_action :set_workstation, only: %i[show edit update destroy]

    def index
      @workstations = if current_store
        Workstation.where(store: accessible_store_scope).order(:code)
      else
        Workstation.where(store: accessible_store_scope).order(:code)
      end
    end

    def show; end

    def new
      @workstation = Workstation.new(store: current_store)
    end

    def create
      @workstation = Workstation.new(workstation_params.merge(store: current_store))
      if @workstation.save
        Audit::Recorder.record!(
          action: "workstations.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: @workstation.store,
          workstation: @workstation,
          subject: @workstation,
          after_values: { code: @workstation.code, name: @workstation.name }
        )
        redirect_to admin_workstation_path(@workstation), notice: "Workstation created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        if @workstation.update(workstation_params)
          Audit::Recorder.record!(
            action: "workstations.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: @workstation.store,
            workstation: @workstation,
            subject: @workstation
          )
          redirect_to admin_workstation_path(@workstation), notice: "Workstation updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @workstation.update!(active: false, deactivated_at: Time.current, deactivated_by: current_user)
      Audit::Recorder.record!(
        action: "workstations.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: @workstation.store,
        workstation: @workstation,
        subject: @workstation
      )
      redirect_to admin_workstations_path, notice: "Workstation deactivated."
    end

    private

    def set_workstation
      @workstation = Workstation.where(store: accessible_store_scope).find(params[:id])
    end

    def accessible_store_scope
      if Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: "workstations.view", store: nil)
        Store.all
      else
        accessible_stores
      end
    end

    def workstation_params
      params.require(:workstation).permit(:code, :name, :description, :lock_version)
    end
  end
end
