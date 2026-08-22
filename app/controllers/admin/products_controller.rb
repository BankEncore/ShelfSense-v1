# frozen_string_literal: true

module Admin
  class ProductsController < BaseController
    include PurchasingHelper

    before_action -> { require_permission!("products.view") }, only: %i[index show]
    before_action -> { require_permission!("products.create") }, only: %i[new create]
    before_action -> { require_permission!("products.update") }, only: %i[edit update]
    before_action -> { require_permission!("products.discontinue") }, only: %i[discontinue reactivate]
    before_action -> { require_permission!("products.update") }, only: :destroy
    before_action :set_product, only: %i[show edit update destroy discontinue reactivate]

    def index
      @index = Products::AdminIndexQuery.call(
        q: params[:q],
        status: params[:status],
        merchandise_category_id: params[:merchandise_category_id],
        page: params[:page]
      )
      @products = @index.records.includes(:merchandise_category)
      @variant_counts = ProductVariant.where(product_id: @products.map(&:id)).group(:product_id).count
      @merchandise_categories = MerchandiseCategory.assignable.admin_ordered
      @show_inventory = inventory_display_enabled?
      @on_hand_by_product_id = load_product_on_hand_totals(@products.map(&:id)) if @show_inventory
    end

    def show
      @product_variants = @product.product_variants
        .includes(:merchandise_class, :merchandise_condition, :tax_class_override, merchandise_class: [ :department, :default_tax_class ])
        .order(:sku)
      @recent_audit_events = recent_product_audit_events
      @show_inventory = inventory_display_enabled?
      @balances_by_variant_id = load_variant_balances(@product_variants.map(&:id)) if @show_inventory
      load_product_purchasing_actions
    end

    def new
      @product = Product.new(status: "draft")
      load_form_options
    end

    def create
      attrs = product_attributes
      if @money_error
        @product = Product.new(attrs)
        @product.errors.add(:list_price, @money_error)
        load_form_options
        render :new, status: :unprocessable_entity
        return
      end

      @product = Products::Create.call(
        attributes: attrs.except(:industry_identifier, :lookup_code),
        actor: current_user,
        industry_identifier: attrs[:industry_identifier],
        lookup_code: attrs[:lookup_code]
      )
      redirect_to admin_product_path(@product), notice: "Product created."
    rescue Products::Create::Error => e
      @product = Product.new(attrs)
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
        if @money_error
          render_form_with_money_error(:edit)
          return
        end

        if attrs[:status] == "discontinued"
          @product.errors.add(:status, "use Discontinue instead")
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

        if @product.status == "discontinued" && attrs[:status].present? && attrs[:status] != "discontinued"
          @product.errors.add(:status, "use Reactivate instead")
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

        begin
          Products::Update.call(
            product: @product,
            attributes: attrs.to_h.symbolize_keys,
            actor: current_user,
            store: current_store
          )
          redirect_to admin_product_path(@product), notice: "Product updated."
        rescue Products::Update::Error => e
          @product.errors.add(:base, e.message)
          load_form_options
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def discontinue
      rescue_stale do
        before_status = @product.status
        mutate_and_audit!(
          @product,
          action: "products.discontinue",
          before_values: { status: before_status },
          after_values: { status: "discontinued" }
        ) { @product.update!(status: "discontinued") }
        redirect_to admin_product_path(@product), notice: "Product discontinued."
      end
    end

    def reactivate
      rescue_stale do
        unless @product.status == "discontinued"
          redirect_to admin_product_path(@product), alert: "Only discontinued products can be reactivated."
          return
        end

        if @product.merchandise_category.present? && !@product.merchandise_category.assignable?
          redirect_to admin_product_path(@product),
                      alert: "Cannot reactivate: merchandise category must be active."
          return
        end

        before_status = @product.status
        mutate_and_audit!(
          @product,
          action: "products.reactivate",
          before_values: { status: before_status },
          after_values: { status: "active" }
        ) { @product.update!(status: "active") }
        redirect_to admin_product_path(@product), notice: "Product reactivated."
      end
    end

    def destroy
      unless @product.draft?
        redirect_to admin_product_path(@product), alert: "Only draft products can be deleted."
        return
      end

      primary_identifier = @product.primary_identifier
      industry_identifier = @product.industry_identifier
      name = @product.name
      Product.transaction do
        Identifiers::Registry.retire!(value: primary_identifier)
        Identifiers::Registry.retire!(value: industry_identifier) if industry_identifier.present?
        @product.destroy!
        Audit::Recorder.record!(
          action: "products.destroy",
          outcome: "succeeded",
          actor_user: current_user,
          actor_label: current_user.display_name,
          store: current_store,
          after_values: {
            primary_identifier: primary_identifier,
            industry_identifier: industry_identifier,
            name: name
          }
        )
      end
      redirect_to admin_products_path, notice: "Draft product deleted."
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotFound,
           ActiveRecord::StatementInvalid => e
      redirect_to admin_product_path(@product), alert: e.message
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def load_form_options
      @merchandise_categories = MerchandiseCategory.assignable.admin_ordered
    end

    def recent_product_audit_events
      return [] unless effective_permissions.include?("audit_events.view")

      scope = AuditEvent.where(subject_type: "Product", subject_id: @product.id)
      global_view = Authorization::PermissionEvaluator.allowed?(
        user: current_user,
        permission_key: "audit_events.view",
        store: nil
      )
      unless global_view
        scope = scope.where(store_id: accessible_stores.select(:id))
      end
      scope.order(occurred_at: :desc).limit(5).to_a
    end

    def product_attributes
      attrs = product_params.except(:lock_version).to_h.symbolize_keys
      attrs[:status] = "draft" if attrs[:status].blank?
      attrs
    end

    def product_params
      @money_error = nil
      @list_price_raw = params.dig(:product, :list_price)
      permitted = params.require(:product).permit(
        :name, :subtitle, :description, :brand_name, :product_model, :merchandise_category_id,
        :list_price, :list_price_cents, :release_date, :status, :variant_option_name_1, :variant_option_name_2,
        :industry_identifier, :lookup_code, :lock_version
      )

      if permitted.key?(:list_price) || params[:product]&.key?(:list_price)
        raw = permitted.delete(:list_price)
        raw = params.dig(:product, :list_price) if raw.nil?
        begin
          permitted[:list_price_cents] = Money::ParseCents.call(raw)
        rescue Money::ParseCents::Error => e
          @money_error = e.message
          permitted.delete(:list_price_cents)
        end
      end

      %i[merchandise_category_id list_price_cents release_date subtitle description brand_name
         product_model variant_option_name_1 variant_option_name_2 industry_identifier
         lookup_code].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted
    end

    def render_form_with_money_error(template)
      @product ||= Product.new
      @product.assign_attributes(product_params.except(:list_price_cents, :lock_version)) if params[:product]
      @product.errors.add(:list_price, @money_error)
      load_form_options
      render template, status: :unprocessable_entity
    end

    def inventory_display_enabled?
      current_store.present? && effective_permissions.include?("inventory.view")
    end

    def load_product_on_hand_totals(product_ids)
      return {} if product_ids.empty?

      InventoryBalance.joins(:product_variant)
        .where(store_id: current_store.id, product_variants: { product_id: product_ids })
        .group("product_variants.product_id")
        .sum(:on_hand_quantity)
    end

    def load_variant_balances(variant_ids)
      return {} if variant_ids.empty?

      InventoryBalance.where(store_id: current_store.id, product_variant_id: variant_ids).index_by(&:product_variant_id)
    end

    def load_product_purchasing_actions
      @stock_orderable_variants = []
      @requestable_variants = []
      return if current_store.blank?

      if effective_permissions.include?("orders.manage")
        @stock_orderable_variants = @product_variants.select { |v| stock_orderable_variant?(v) }
      end
      if effective_permissions.include?("customer_requests.manage")
        @requestable_variants = @product_variants.select { |v|
          customer_requestable_variant?(v, store: current_store)
        }
      end
      @single_stock_orderable = @stock_orderable_variants.one? ? @stock_orderable_variants.first : nil
      @single_requestable = @requestable_variants.one? ? @requestable_variants.first : nil
    end
  end
end
