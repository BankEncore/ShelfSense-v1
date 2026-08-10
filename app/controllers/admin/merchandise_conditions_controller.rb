# frozen_string_literal: true

module Admin
  class MerchandiseConditionsController < BaseController
    before_action -> { require_permission!("merchandise_conditions.view") }, only: %i[index show]
    before_action -> { require_permission!("merchandise_conditions.create") }, only: %i[new create]
    before_action -> { require_permission!("merchandise_conditions.update") }, only: %i[edit update]
    before_action -> { require_permission!("merchandise_conditions.deactivate") }, only: :destroy
    before_action :set_merchandise_condition, only: %i[show edit update destroy]

    def index
      @merchandise_conditions = MerchandiseCondition.order(:display_order, :code)
    end

    def show; end

    def new
      @merchandise_condition = MerchandiseCondition.new(
        department_basis: "standard",
        price_adjustment_bps: 10_000,
        display_order: 0
      )
    end

    def create
      @merchandise_condition = MerchandiseCondition.new(merchandise_condition_params.except(:lock_version))
      if @merchandise_condition.save
        Audit::Recorder.record!(
          action: "merchandise_conditions.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: @merchandise_condition,
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
        before = @merchandise_condition.attributes.slice(
          "code", "name", "description", "department_basis", "price_adjustment_bps", "display_order"
        )
        if @merchandise_condition.update(merchandise_condition_params)
          Audit::Recorder.record!(
            action: "merchandise_conditions.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: current_store,
            subject: @merchandise_condition,
            before_values: before,
            after_values: @merchandise_condition.attributes.slice(*before.keys)
          )
          redirect_to admin_merchandise_condition_path(@merchandise_condition), notice: "Merchandise condition updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @merchandise_condition.update!(active: false)
      Audit::Recorder.record!(
        action: "merchandise_conditions.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        subject: @merchandise_condition
      )
      redirect_to admin_merchandise_conditions_path, notice: "Merchandise condition deactivated."
    end

    private

    def set_merchandise_condition
      @merchandise_condition = MerchandiseCondition.find(params[:id])
    end

    def merchandise_condition_params
      params.require(:merchandise_condition).permit(
        :code, :name, :description, :department_basis, :price_adjustment_bps,
        :display_order, :lock_version
      )
    end
  end
end
