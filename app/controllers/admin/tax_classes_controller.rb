# frozen_string_literal: true

module Admin
  class TaxClassesController < BaseController
    before_action -> { require_permission!("tax_classes.view") }, only: %i[index show]
    before_action -> { require_permission!("tax_classes.create") }, only: %i[new create]
    before_action -> { require_permission!("tax_classes.update") }, only: %i[edit update]
    before_action -> { require_permission!("tax_classes.deactivate") }, only: :destroy
    before_action :set_tax_class, only: %i[show edit update destroy]

    def index
      @tax_classes = TaxClass.order(:display_order, :code)
    end

    def show; end

    def new
      @tax_class = TaxClass.new(display_order: 0)
    end

    def create
      @tax_class = TaxClass.new(tax_class_params.except(:lock_version))
      if @tax_class.save
        Audit::Recorder.record!(
          action: "tax_classes.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: @tax_class,
          after_values: { code: @tax_class.code, name: @tax_class.name }
        )
        redirect_to admin_tax_class_path(@tax_class), notice: "Tax class created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        before = @tax_class.attributes.slice("code", "name", "description", "display_order")
        if @tax_class.update(tax_class_params)
          Audit::Recorder.record!(
            action: "tax_classes.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: current_store,
            subject: @tax_class,
            before_values: before,
            after_values: @tax_class.attributes.slice(*before.keys)
          )
          redirect_to admin_tax_class_path(@tax_class), notice: "Tax class updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @tax_class.update!(active: false)
      Audit::Recorder.record!(
        action: "tax_classes.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        subject: @tax_class
      )
      redirect_to admin_tax_classes_path, notice: "Tax class deactivated."
    end

    private

    def set_tax_class
      @tax_class = TaxClass.find(params[:id])
    end

    def tax_class_params
      params.require(:tax_class).permit(:code, :name, :description, :display_order, :lock_version)
    end
  end
end
