# frozen_string_literal: true

module Admin
  class MerchandiseClassesController < BaseController
    before_action -> { require_permission!("merchandise_classes.view") }, only: %i[index show]
    before_action -> { require_permission!("merchandise_classes.create") }, only: %i[new create]
    before_action -> { require_permission!("merchandise_classes.update") }, only: %i[edit update]
    before_action -> { require_permission!("merchandise_classes.deactivate") }, only: :destroy
    before_action :set_merchandise_class, only: %i[show edit update destroy]

    def index
      @merchandise_classes = MerchandiseClass.order(:display_order, :code)
    end

    def show; end

    def new
      @merchandise_class = MerchandiseClass.new(
        inventory_tracking_mode: "quantity",
        pricing_method: "fixed",
        display_order: 0
      )
      load_form_options
    end

    def create
      @merchandise_class = MerchandiseClass.new(merchandise_class_params.except(:lock_version))
      if @merchandise_class.save
        Audit::Recorder.record!(
          action: "merchandise_classes.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: @merchandise_class,
          after_values: { code: @merchandise_class.code, name: @merchandise_class.name }
        )
        redirect_to admin_merchandise_class_path(@merchandise_class), notice: "Merchandise class created."
      else
        load_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_form_options
    end

    def update
      rescue_stale do
        before = @merchandise_class.attributes.slice(
          "code", "name", "description", "inventory_tracking_mode", "pricing_method",
          "default_standard_department_id", "default_used_department_id",
          "used_merchandise_allowed", "buyback_allowed", "default_returnable", "display_order"
        )
        if @merchandise_class.update(merchandise_class_params)
          Audit::Recorder.record!(
            action: "merchandise_classes.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: current_store,
            subject: @merchandise_class,
            before_values: before,
            after_values: @merchandise_class.attributes.slice(*before.keys)
          )
          redirect_to admin_merchandise_class_path(@merchandise_class), notice: "Merchandise class updated."
        else
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @merchandise_class.update!(active: false)
      Audit::Recorder.record!(
        action: "merchandise_classes.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        subject: @merchandise_class
      )
      redirect_to admin_merchandise_classes_path, notice: "Merchandise class deactivated."
    end

    private

    def set_merchandise_class
      @merchandise_class = MerchandiseClass.find(params[:id])
    end

    def load_form_options
      @departments = Department.assignable.order(:display_order, :code)
    end

    def merchandise_class_params
      permitted = params.require(:merchandise_class).permit(
        :code, :name, :description, :inventory_tracking_mode, :pricing_method,
        :default_standard_department_id, :default_used_department_id,
        :used_merchandise_allowed, :buyback_allowed, :default_returnable,
        :display_order, :lock_version
      )
      %i[default_standard_department_id default_used_department_id].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end
  end
end
