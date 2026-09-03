# frozen_string_literal: true

module Admin
  class MerchandiseConditionsController < BaseController
    before_action -> { require_permission!("merchandise_conditions.view") }, only: %i[index show]
    before_action -> { require_permission!("merchandise_conditions.create") }, only: %i[new create]
    before_action -> { require_permission!("merchandise_conditions.update") }, only: %i[edit update]
    before_action -> { require_permission!("merchandise_conditions.deactivate") }, only: %i[destroy reactivate]
    before_action :set_merchandise_condition, only: %i[show edit update destroy reactivate]

    def index
      @merchandise_conditions = MerchandiseCondition.admin_ordered
    end

    def show; end

    def new
      @merchandise_condition = MerchandiseCondition.new(
        price_adjustment_bps: 10_000,
        display_order: 0
      )
    end

    def create
      @merchandise_condition = MerchandiseCondition.new(merchandise_condition_params.except(:lock_version))
      if create_and_audit!(
        @merchandise_condition,
        action: "merchandise_conditions.create",
        after_values: { code: @merchandise_condition.code, name: @merchandise_condition.name }
      )
        redirect_to admin_merchandise_condition_path(@merchandise_condition), notice: "Merchandise condition created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      rescue_stale do
        before_name = @merchandise_condition.name
        if save_and_audit!(
          @merchandise_condition,
          attrs: merchandise_condition_params.except(:code),
          action: "merchandise_conditions.update",
          before_keys: %w[name description price_adjustment_bps display_order]
        )
          if @merchandise_condition.name != before_name
            MerchandiseConditions::RefreshVariantNames.call(condition: @merchandise_condition)
          end
          redirect_to admin_merchandise_condition_path(@merchandise_condition), notice: "Merchandise condition updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@merchandise_condition, action: "merchandise_conditions.deactivate") do
        @merchandise_condition.update!(active: false)
      end
      redirect_to admin_merchandise_conditions_path, notice: "Merchandise condition deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @merchandise_condition,
        permission_key: "merchandise_conditions.deactivate",
        audit_action: "merchandise_conditions.reactivate",
        redirect_path: admin_merchandise_condition_path(@merchandise_condition)
      )
    end

    private

    def set_merchandise_condition
      @merchandise_condition = MerchandiseCondition.find(params[:id])
    end

    def merchandise_condition_params
      params.require(:merchandise_condition).permit(
        :code, :name, :description, :price_adjustment_bps,
        :display_order, :lock_version
      )
    end
  end
end
