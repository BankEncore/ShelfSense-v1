# frozen_string_literal: true

module Admin
  class ProductFormsController < BaseController
    before_action -> { require_permission!("product_forms.view") }, only: %i[index show]
    before_action -> { require_permission!("product_forms.update") }, only: %i[edit update]
    before_action -> { require_permission!("product_forms.deactivate") }, only: %i[destroy reactivate]
    before_action :set_product_form, only: %i[show edit update destroy reactivate]

    def index
      @product_forms = ProductForm.admin_ordered
    end

    def show; end

    def edit; end

    def update
      rescue_stale do
        if save_and_audit!(
          @product_form,
          attrs: product_form_params.except(:code),
          action: "product_forms.update",
          before_keys: %w[name display_order active]
        )
          redirect_to admin_product_form_path(@product_form), notice: "Product form updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@product_form, action: "product_forms.deactivate") do
        @product_form.update!(active: false)
      end
      redirect_to admin_product_forms_path, notice: "Product form deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @product_form,
        permission_key: "product_forms.deactivate",
        audit_action: "product_forms.reactivate",
        redirect_path: admin_product_form_path(@product_form)
      )
    end

    private

    def set_product_form
      @product_form = ProductForm.find(params[:id])
    end

    def product_form_params
      params.require(:product_form).permit(:code, :name, :display_order, :lock_version)
    end
  end
end
