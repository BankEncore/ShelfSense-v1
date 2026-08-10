# frozen_string_literal: true

module Admin
  class MerchandiseCategoriesController < BaseController
    before_action -> { require_permission!("merchandise_categories.view") }, only: %i[index show]
    before_action -> { require_permission!("merchandise_categories.create") }, only: %i[new create]
    before_action -> { require_permission!("merchandise_categories.update") }, only: %i[edit update]
    before_action -> { require_permission!("merchandise_categories.deactivate") }, only: :destroy
    before_action :set_merchandise_category, only: %i[show edit update destroy]

    def index
      @merchandise_categories = MerchandiseCategory.order(:display_order, :name)
    end

    def show; end

    def new
      @merchandise_category = MerchandiseCategory.new(display_order: 0)
      load_form_options
    end

    def create
      @merchandise_category = MerchandiseCategory.new(merchandise_category_params.except(:lock_version))
      if @merchandise_category.save
        Audit::Recorder.record!(
          action: "merchandise_categories.create",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: @merchandise_category,
          after_values: { code: @merchandise_category.code, name: @merchandise_category.name }
        )
        redirect_to admin_merchandise_category_path(@merchandise_category), notice: "Merchandise category created."
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
        before = @merchandise_category.attributes.slice(
          "code", "name", "description", "parent_id", "default_merchandise_class_id", "display_order"
        )
        if @merchandise_category.update(merchandise_category_params)
          Audit::Recorder.record!(
            action: "merchandise_categories.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: current_store,
            subject: @merchandise_category,
            before_values: before,
            after_values: @merchandise_category.attributes.slice(*before.keys)
          )
          redirect_to admin_merchandise_category_path(@merchandise_category), notice: "Merchandise category updated."
        else
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      @merchandise_category.update!(active: false)
      Audit::Recorder.record!(
        action: "merchandise_categories.deactivate",
        outcome: "succeeded",
        actor_user: current_user,
        actor_label: current_user.display_name,
        store: current_store,
        subject: @merchandise_category
      )
      redirect_to admin_merchandise_categories_path, notice: "Merchandise category deactivated."
    end

    private

    def set_merchandise_category
      @merchandise_category = MerchandiseCategory.find(params[:id])
    end

    def load_form_options
      scope = MerchandiseCategory.order(:display_order, :name)
      scope = scope.where.not(id: @merchandise_category.id) if @merchandise_category&.persisted?
      @parent_options = scope
      @merchandise_classes = MerchandiseClass.assignable.order(:display_order, :code)
    end

    def merchandise_category_params
      permitted = params.require(:merchandise_category).permit(
        :code, :name, :description, :parent_id, :default_merchandise_class_id,
        :display_order, :lock_version
      )
      %i[code parent_id default_merchandise_class_id].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end
  end
end
