# frozen_string_literal: true

module Admin
  class DepartmentsController < BaseController
    before_action -> { require_permission!("departments.view") }, only: %i[index show]
    before_action -> { require_permission!("departments.create") }, only: %i[new create]
    before_action -> { require_permission!("departments.update") }, only: %i[edit update]
    before_action -> { require_permission!("departments.deactivate") }, only: %i[destroy reactivate]
    before_action :set_department, only: %i[show edit update destroy reactivate]

    def index
      @departments = Department.order(:display_order, :code)
    end

    def show; end

    def new
      @department = Department.new(display_order: 0)
      load_form_options
    end

    def create
      @department = Department.new(department_params.except(:lock_version))
      if create_and_audit!(
        @department,
        action: "departments.create",
        after_values: { code: @department.code, name: @department.name }
      )
        redirect_to admin_department_path(@department), notice: "Department created."
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
        if save_and_audit!(
          @department,
          attrs: department_params.except(:code),
          action: "departments.update",
          before_keys: audit_attribute_keys - %w[code]
        )
          redirect_to admin_department_path(@department), notice: "Department updated."
        else
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@department, action: "departments.deactivate") { @department.update!(active: false) }
      redirect_to admin_departments_path, notice: "Department deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @department,
        permission_key: "departments.deactivate",
        audit_action: "departments.reactivate",
        redirect_path: admin_department_path(@department)
      )
    end

    private

    def set_department
      @department = Department.find(params[:id])
    end

    def load_form_options
      @tax_classes = TaxClass.assignable.order(:display_order, :code)
      @gl_accounts = GlAccount.assignable.order(:account_number)
    end

    def audit_attribute_keys
      %w[
        code department_number name description default_tax_class_id default_target_margin_bps
        inventory_asset_gl_account_id cost_of_goods_sold_gl_account_id sales_revenue_gl_account_id
        sales_returns_gl_account_id receiving_clearing_gl_account_id freight_in_gl_account_id
        inventory_shrinkage_gl_account_id inventory_adjustment_gain_gl_account_id
        inventory_adjustment_loss_gl_account_id inventory_write_down_gl_account_id display_order
      ]
    end

    def department_params
      permitted = params.require(:department).permit(
        :code, :department_number, :name, :description, :default_tax_class_id,
        :default_target_margin_bps, :inventory_asset_gl_account_id, :cost_of_goods_sold_gl_account_id,
        :sales_revenue_gl_account_id, :sales_returns_gl_account_id, :receiving_clearing_gl_account_id,
        :freight_in_gl_account_id, :inventory_shrinkage_gl_account_id,
        :inventory_adjustment_gain_gl_account_id, :inventory_adjustment_loss_gl_account_id,
        :inventory_write_down_gl_account_id, :display_order, :lock_version
      )
      blankable = %i[
        department_number default_target_margin_bps inventory_asset_gl_account_id
        cost_of_goods_sold_gl_account_id sales_revenue_gl_account_id sales_returns_gl_account_id
        receiving_clearing_gl_account_id freight_in_gl_account_id inventory_shrinkage_gl_account_id
        inventory_adjustment_gain_gl_account_id inventory_adjustment_loss_gl_account_id
        inventory_write_down_gl_account_id
      ]
      blankable.each { |key| permitted[key] = nil if permitted[key].blank? }
      permitted
    end
  end
end
