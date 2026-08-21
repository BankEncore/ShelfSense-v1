# frozen_string_literal: true

module Admin
  class MerchandiseCategoriesController < BaseController
    before_action -> { require_permission!("merchandise_categories.view") }, only: %i[index show]
    before_action -> { require_permission!("merchandise_categories.create") }, only: %i[new create]
    before_action -> { require_permission!("merchandise_categories.update") }, only: %i[edit update]
    before_action -> { require_permission!("merchandise_categories.deactivate") }, only: %i[destroy reactivate]
    before_action :set_merchandise_category, only: %i[show edit update destroy reactivate]

    def index
      @merchandise_categories = MerchandiseCategory.admin_ordered
    end

    def show; end

    def new
      @merchandise_category = MerchandiseCategory.new(display_order: 0)
      load_form_options
    end

    def create
      @merchandise_category = MerchandiseCategory.new(merchandise_category_params.except(:lock_version))
      if create_and_audit!(
        @merchandise_category,
        action: "merchandise_categories.create",
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
        if save_and_audit!(
          @merchandise_category,
          attrs: merchandise_category_params.except(:code),
          action: "merchandise_categories.update",
          before_keys: %w[name description parent_id default_standard_merchandise_class_id default_used_merchandise_class_id display_order]
        )
          redirect_to admin_merchandise_category_path(@merchandise_category), notice: "Merchandise category updated."
        else
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def destroy
      mutate_and_audit!(@merchandise_category, action: "merchandise_categories.deactivate") do
        @merchandise_category.update!(active: false)
      end
      redirect_to admin_merchandise_categories_path, notice: "Merchandise category deactivated."
    end

    def reactivate
      reactivate_configuration!(
        @merchandise_category,
        permission_key: "merchandise_categories.deactivate",
        audit_action: "merchandise_categories.reactivate",
        redirect_path: admin_merchandise_category_path(@merchandise_category)
      )
    end

    private

    def set_merchandise_category
      @merchandise_category = MerchandiseCategory.find(params[:id])
    end

    def load_form_options
      scope = MerchandiseCategory.admin_ordered
      scope = scope.where.not(id: @merchandise_category.id) if @merchandise_category&.persisted?
      @parent_options = scope
      @merchandise_classes = MerchandiseClass.assignable.admin_ordered
    end

    def merchandise_category_params
      permitted = params.require(:merchandise_category).permit(
        :code, :name, :description, :parent_id,
        :default_standard_merchandise_class_id, :default_used_merchandise_class_id,
        :display_order, :lock_version
      )
      %i[code parent_id default_standard_merchandise_class_id default_used_merchandise_class_id].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end
  end
end
