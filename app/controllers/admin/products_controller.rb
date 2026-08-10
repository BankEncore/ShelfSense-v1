# frozen_string_literal: true

module Admin
  class ProductsController < BaseController
    before_action -> { require_permission!("products.view") }, only: %i[index show]
    before_action -> { require_permission!("products.create") }, only: %i[new create]
    before_action -> { require_permission!("products.update") }, only: %i[edit update]
    before_action -> { require_permission!("products.discontinue") }, only: :discontinue
    before_action -> { require_permission!("products.update") }, only: :destroy
    before_action :set_product, only: %i[show edit update destroy discontinue]

    def index
      @products = Product.order(:name)
    end

    def show
      @product_variants = @product.product_variants.order(:sku)
    end

    def new
      @product = Product.new(status: "draft")
      load_form_options
    end

    def create
      @product = Products::Create.call(
        attributes: product_attributes,
        actor: current_user,
        identifier_mode: identifier_mode,
        external_identifier: external_identifier.presence
      )
      redirect_to admin_product_path(@product), notice: "Product created."
    rescue Products::Create::Error => e
      @product = Product.new(product_attributes)
      @product.errors.add(:base, e.message)
      load_form_options
      render :new, status: :unprocessable_entity
    end

    def edit
      load_form_options
    end

    def update
      rescue_stale do
        attrs = product_params
        if attrs[:status] == "discontinued"
          @product.errors.add(:status, "use Discontinue instead")
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

        before = @product.attributes.slice(*audit_attribute_keys)
        if @product.update(attrs)
          Audit::Recorder.record!(
            action: "products.update",
            outcome: "succeeded",
            actor_user: current_user,
            actor_label: current_user.display_name,
            store: current_store,
            subject: @product,
            before_values: before,
            after_values: @product.attributes.slice(*before.keys)
          )
          redirect_to admin_product_path(@product), notice: "Product updated."
        else
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def discontinue
      rescue_stale do
        before_status = @product.status
        @product.update!(status: "discontinued")
        Audit::Recorder.record!(
          action: "products.discontinue",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          subject: @product,
          before_values: { status: before_status },
          after_values: { status: @product.status }
        )
        redirect_to admin_product_path(@product), notice: "Product discontinued."
      end
    end

    def destroy
      unless @product.draft?
        redirect_to admin_product_path(@product), alert: "Only draft products can be deleted."
        return
      end

      primary_identifier = @product.primary_identifier
      name = @product.name
      Product.transaction do
        Identifiers::Registry.retire!(value: primary_identifier)
        @product.destroy!
        Audit::Recorder.record!(
          action: "products.destroy",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          after_values: { primary_identifier: primary_identifier, name: name }
        )
      end
      redirect_to admin_products_path, notice: "Draft product deleted."
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotFound => e
      redirect_to admin_product_path(@product), alert: e.message
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def load_form_options
      @merchandise_categories = MerchandiseCategory.assignable.order(:display_order, :name)
    end

    def audit_attribute_keys
      %w[
        name subtitle description brand_name product_model merchandise_category_id
        list_price_cents release_date status variant_option_name_1 variant_option_name_2
      ]
    end

    def identifier_mode
      params.dig(:product, :identifier_mode).presence || params[:identifier_mode].presence || "enter"
    end

    def external_identifier
      params.dig(:product, :external_identifier).presence || params[:external_identifier]
    end

    def product_attributes
      attrs = product_params.except(:lock_version).to_h.symbolize_keys
      attrs[:status] = "draft" if attrs[:status].blank?
      attrs
    end

    def product_params
      permitted = params.require(:product).permit(
        :name, :subtitle, :description, :brand_name, :product_model, :merchandise_category_id,
        :list_price_cents, :release_date, :status, :variant_option_name_1, :variant_option_name_2,
        :lock_version
      )
      %i[merchandise_category_id list_price_cents release_date subtitle description brand_name
         product_model variant_option_name_1 variant_option_name_2].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end
  end
end
