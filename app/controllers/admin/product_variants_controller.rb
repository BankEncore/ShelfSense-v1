# frozen_string_literal: true

module Admin
  class ProductVariantsController < BaseController
    before_action -> { require_permission!("product_variants.view") }, only: %i[index show]
    before_action -> { require_permission!("product_variants.create") }, only: %i[new create]
    before_action -> { require_permission!("product_variants.update") }, only: %i[edit update]
    before_action -> { require_permission!("product_variants.discontinue") }, only: :discontinue
    before_action -> { require_permission!("product_variants.update") }, only: :destroy
    before_action :set_product, only: %i[index new create]
    before_action :set_product_variant, only: %i[show edit update destroy discontinue]

    def index
      @product_variants = @product.product_variants.order(:sku)
    end

    def show; end

    def new
      @product_variant = @product.product_variants.build(status: "draft", variant_type: "standard")
      load_form_options
    end

    def create
      @product_variant = ProductVariants::Create.call(
        product: @product,
        attributes: variant_attributes,
        actor: current_user
      )
      redirect_to admin_product_variant_path(@product_variant), notice: "Product variant created."
    rescue ProductVariants::Create::Error => e
      @product_variant = @product.product_variants.build(variant_attributes)
      @product_variant.errors.add(:base, e.message)
      load_form_options
      render :new, status: :unprocessable_entity
    end

    def edit
      @product = @product_variant.product
      load_form_options
    end

    def update
      rescue_stale do
        attrs = product_variant_params
        if attrs[:status] == "discontinued"
          @product_variant.errors.add(:status, "use Discontinue instead")
          @product = @product_variant.product
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

        ProductVariants::Update.call(
          variant: @product_variant,
          attributes: attrs.except(:sku).to_h.symbolize_keys,
          actor: current_user,
          store: current_store
        )
        redirect_to admin_product_variant_path(@product_variant), notice: "Product variant updated."
      rescue ProductVariants::Update::Error => e
        @product_variant.errors.add(:base, e.message)
        @product = @product_variant.product
        load_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def discontinue
      rescue_stale do
        before_status = @product_variant.status
        mutate_and_audit!(
          @product_variant,
          action: "product_variants.discontinue",
          before_values: { status: before_status },
          after_values: { status: "discontinued" }
        ) { @product_variant.update!(status: "discontinued") }
        redirect_to admin_product_variant_path(@product_variant), notice: "Product variant discontinued."
      end
    end

    def destroy
      unless @product_variant.draft?
        redirect_to admin_product_variant_path(@product_variant), alert: "Only draft variants can be deleted."
        return
      end

      product = @product_variant.product
      ProductVariant.transaction do
        Identifiers::Registry.retire!(value: @product_variant.sku)
        if @product_variant.industry_identifier.present?
          Identifiers::Registry.retire!(value: @product_variant.industry_identifier)
        end
        sku = @product_variant.sku
        @product_variant.destroy!
        Audit::Recorder.record!(
          action: "product_variants.destroy",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          after_values: { sku: sku, product_id: product.id }
        )
      end
      redirect_to admin_product_path(product), notice: "Draft variant deleted."
    rescue ActiveRecord::RecordNotFound => e
      redirect_to admin_products_path, alert: e.message
    end

    private

    def set_product
      @product = Product.find(params[:product_id])
    end

    def set_product_variant
      @product_variant = ProductVariant.find(params[:id])
    end

    def load_form_options
      @merchandise_conditions = MerchandiseCondition.assignable.order(:display_order, :code)
      @merchandise_classes = MerchandiseClass.assignable.order(:display_order, :code)
      @departments = Department.assignable.order(:display_order, :code)
      @tax_classes = TaxClass.assignable.order(:display_order, :code)
    end

    def audit_attribute_keys
      %w[
        variant_type name option_value_1 option_value_2 merchandise_condition_id merchandise_class_id
        department_id tax_class_id regular_price_cents status industry_identifier
      ]
    end

    def variant_attributes
      product_variant_params.except(:lock_version, :sku).to_h.symbolize_keys
    end

    def product_variant_params
      permitted = params.require(:product_variant).permit(
        :variant_type, :name, :option_value_1, :option_value_2, :merchandise_condition_id,
        :merchandise_class_id, :department_id, :tax_class_id, :regular_price_cents,
        :industry_identifier, :status, :lock_version
      )
      %i[name option_value_1 option_value_2 merchandise_condition_id merchandise_class_id department_id tax_class_id
         regular_price_cents industry_identifier].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end
  end
end
