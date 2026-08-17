# frozen_string_literal: true

module Admin
  class RegistersController < BaseController
    before_action -> { require_permission!("registers.view") }, only: %i[index show]
    before_action -> { require_permission!("registers.create") }, only: %i[new create]
    before_action -> { require_permission!("registers.manage") }, only: %i[edit update]
    before_action -> { require_permission!("registers.deactivate") }, only: :destroy
    before_action :require_store_context, except: %i[index show]
    before_action :set_register, only: %i[show edit update destroy]

    def index
      @registers = Register.where(store: accessible_store_scope).order(:register_number)
    end

    def show; end

    def new
      @register = Register.new(store: current_store, register_number: next_register_number(current_store))
    end

    def create
      @register = Register.new(register_params.merge(store: current_store))
      if @register.save
        Audit::Recorder.record!(
          action: "registers.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: @register.store,
          register: @register,
          subject: @register,
          after_values: { register_number: @register.register_number, name: @register.name }
        )
        redirect_to admin_register_path(@register), notice: "Register created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        if @register.update(register_params)
          Audit::Recorder.record!(
            action: "registers.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: @register.store,
            register: @register,
            subject: @register
          )
          redirect_to admin_register_path(@register), notice: "Register updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @register.update!(active: false, deactivated_at: Time.current, deactivated_by: current_user)
      Audit::Recorder.record!(
        action: "registers.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: @register.store,
        register: @register,
        subject: @register
      )
      redirect_to admin_registers_path, notice: "Register deactivated."
    end

    private

    def set_register
      @register = Register.where(store: accessible_store_scope).find(params[:id])
    end

    def accessible_store_scope
      if Authorization::PermissionEvaluator.allowed?(user: current_user, permission_key: "registers.view", store: nil)
        Store.all
      else
        accessible_stores
      end
    end

    def register_params
      permitted = [ :name, :description, :lock_version ]
      permitted << :register_number if @register.nil? || @register.receipt_sequence.to_i.zero?
      params.require(:register).permit(*permitted)
    end

    def next_register_number(store)
      return "01" unless store

      existing = store.registers.pluck(:register_number)
      n = 1
      loop do
        candidate = format("%02d", n)
        return candidate unless existing.include?(candidate)

        n += 1
      end
    end
  end
end
