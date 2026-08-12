# frozen_string_literal: true

module Admin
  class TaxClassesController < BaseController
    before_action -> { require_permission!("tax_classes.view") }, only: %i[index show]
    before_action -> { require_permission!("tax_classes.create") }, only: %i[new create]
    before_action -> { require_permission!("tax_classes.update") }, only: %i[edit update]
    before_action -> { require_permission!("tax_classes.deactivate") }, only: %i[destroy reactivate]
    before_action :set_tax_class, only: %i[show edit update destroy reactivate]

    def index
      @tax_classes = TaxClass.admin_ordered
    end

    def show; end

    def new
      @tax_class = TaxClass.new(display_order: 0)
    end

    def create
      @tax_class = TaxClass.new(tax_class_params.except(:lock_version))
      if create_and_audit!(
        @tax_class,
        action: "tax_classes.create",
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
        if save_and_audit!(
          @tax_class,
          attrs: tax_class_params.except(:code),
          action: "tax_classes.update",
          before_keys: %w[name description display_order]
        )
          redirect_to admin_tax_class_path(@tax_class), notice: "Tax class updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@tax_class, action: "tax_classes.deactivate") { @tax_class.update!(active: false) }
      redirect_to admin_tax_classes_path, notice: "Tax class deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @tax_class,
        permission_key: "tax_classes.deactivate",
        audit_action: "tax_classes.reactivate",
        redirect_path: admin_tax_class_path(@tax_class)
      )
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
