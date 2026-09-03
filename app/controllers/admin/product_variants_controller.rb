# frozen_string_literal: true

module Admin
  class ProductVariantsController < BaseController
    include PurchasingHelper

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

    def show
      @show_inventory = current_store.present? && effective_permissions.include?("inventory.view")
      load_purchasing_context
      return unless @show_inventory

      @inventory_balance = InventoryBalance.find_by(
        store_id: current_store.id,
        product_variant_id: @product_variant.id
      )
      if @product_variant.derived_inventory_tracking == "individual"
        @on_hand_units = InventoryUnit.on_hand
          .where(store_id: current_store.id, product_variant_id: @product_variant.id)
          .order(:unit_identifier)
      end
    end

    def new
      attrs = redisplay_variant_attrs
      @product_variant = @product.product_variants.build(attrs)
      if params[:refresh_fields].present?
        apply_new_variant_defaults!(@product_variant, mode: refresh_source_mode)
      elsif params[:product_variant].blank?
        apply_new_variant_defaults!(@product_variant, mode: :initial)
      end
      load_form_options
    end

    def create
      if params[:refresh_fields].present?
        attrs = redisplay_variant_attrs
        @product_variant = @product.product_variants.build(attrs)
        apply_new_variant_defaults!(@product_variant, mode: refresh_source_mode)
        load_form_options
        render :new, status: :ok
        return
      end

      attrs = variant_attributes
      if @money_error
        @product_variant = @product.product_variants.build(attrs)
        @product_variant.errors.add(:regular_price, @money_error)
        load_form_options
        render :new, status: :unprocessable_entity
        return
      end

      @product_variant = ProductVariants::Create.call(
        product: @product,
        attributes: attrs,
        actor: current_user
      )
      redirect_to admin_product_variant_path(@product_variant), notice: "Product variant created."
    rescue ProductVariants::Create::Error => e
      @product_variant = @product.product_variants.build(attrs)
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
        if @money_error
          @product = @product_variant.product
          @product_variant.errors.add(:regular_price, @money_error)
          load_form_options
          render :edit, status: :unprocessable_entity
          return
        end

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
      @merchandise_conditions = MerchandiseCondition.assignable.admin_ordered
      @merchandise_classes = MerchandiseClass.assignable.admin_ordered.includes(:department)
      @tax_classes = TaxClass.assignable.admin_ordered
      @tax_inherit_label = tax_inherit_label_for_form
      assign_regular_price_field_value
    end

    # Refresh uses the resolved cents. Validation rerenders keep the raw submitted text.
    def assign_regular_price_field_value
      @regular_price_field_value =
        if params[:refresh_fields].present?
          helpers.money_field_value(@product_variant.regular_price_cents)
        elsif @money_error.present?
          @regular_price_raw
        else
          params.dig(:product_variant, :regular_price).presence ||
            helpers.money_field_value(@product_variant.regular_price_cents)
        end
    end

    def tax_inherit_label_for_form
      klass = @product_variant&.merchandise_class
      tax = klass&.default_tax_class
      return unless tax&.assignable?

      "Inherit — #{tax.admin_label}"
    end

    def refresh_source_mode
      case params[:refresh_source].to_s
      when "merchandise_class" then :merchandise_class
      when "condition" then :condition
      else :variant_type
      end
    end

    # Materialize DefaultResolver results onto an unsaved new-variant form object.
    # mode:
    #   :initial / :variant_type / :merchandise_class — reapply class sticky defaults + price
    #   :condition — keep sticky fields; refresh suggested price only
    def apply_new_variant_defaults!(variant, mode:)
      type = variant.variant_type.presence || "standard"
      condition = variant.merchandise_condition

      case mode
      when :condition
        resolved = ProductVariants::DefaultResolver.resolve(
          product: @product,
          variant_type: type,
          condition: condition,
          merchandise_class: variant.merchandise_class,
          inventory_mode: variant.inventory_mode,
          pricing_method: variant.pricing_method,
          target_margin_bps: variant.target_margin_bps.nil? ? :omitted : variant.target_margin_bps,
          supplier_returnable: variant.supplier_returnable.nil? ? :omitted : variant.supplier_returnable,
          tax_class_override: variant.tax_class_override_id.nil? ? :omitted : variant.tax_class_override,
          regular_price_cents: nil
        )
        variant.regular_price_cents = suggested_price_for_form(type, condition, resolved.suggested_price_cents)
      else
        # :initial, :variant_type, :merchandise_class
        klass =
          if mode == :merchandise_class
            variant.merchandise_class
          else
            nil
          end

        resolved = ProductVariants::DefaultResolver.resolve(
          product: @product,
          variant_type: type,
          condition: condition,
          merchandise_class: klass,
          regular_price_cents: nil
        )

        variant.assign_attributes(
          merchandise_class_id: resolved.merchandise_class&.id,
          inventory_mode: resolved.inventory_mode,
          pricing_method: resolved.pricing_method,
          target_margin_bps: resolved.target_margin_bps,
          supplier_returnable: resolved.supplier_returnable,
          tax_class_override_id: nil,
          regular_price_cents: suggested_price_for_form(type, condition, resolved.suggested_price_cents)
        )
      end
    end

    def suggested_price_for_form(variant_type, condition, suggested_cents)
      return nil if variant_type.to_s == "used" && condition.blank?

      suggested_cents
    end

    def redisplay_variant_attrs
      base = { status: "active", variant_type: "standard" }
      return base unless params[:product_variant].present?

      permitted = params.require(:product_variant).permit(
        :variant_type, :option_value_1, :option_value_2, :merchandise_condition_id,
        :merchandise_class_id, :tax_class_override_id, :inventory_mode, :pricing_method,
        :target_margin_bps, :supplier_returnable, :regular_price, :regular_price_cents,
        :industry_identifier, :status
      ).to_h.symbolize_keys

      if permitted.key?(:regular_price) || params[:product_variant]&.key?(:regular_price)
        raw = permitted.delete(:regular_price)
        raw = params.dig(:product_variant, :regular_price) if raw.nil?
        begin
          permitted[:regular_price_cents] = Money::ParseCents.call(raw) if raw.present?
          permitted[:regular_price_cents] = nil if raw.blank?
        rescue Money::ParseCents::Error
          permitted.delete(:regular_price_cents)
        end
      end

      %i[option_value_1 option_value_2 merchandise_condition_id merchandise_class_id
         tax_class_override_id inventory_mode pricing_method regular_price_cents
         industry_identifier target_margin_bps supplier_returnable].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      if permitted.key?(:supplier_returnable) && !permitted[:supplier_returnable].nil?
        permitted[:supplier_returnable] = ActiveModel::Type::Boolean.new.cast(permitted[:supplier_returnable])
      end
      permitted[:status] = permitted[:status].to_s.strip.presence || "active"
      permitted[:variant_type] = permitted[:variant_type].presence || "standard"
      if permitted[:variant_type].to_s == "standard"
        permitted[:merchandise_condition_id] = nil
      end
      base.merge(permitted.except(:regular_price, :name))
    end

    def variant_attributes
      product_variant_params.except(:lock_version, :sku, :name).to_h.symbolize_keys.tap do |attrs|
        attrs[:status] = attrs[:status].to_s.strip.presence || "active"
      end
    end

    def product_variant_params
      @money_error = nil
      @regular_price_raw = params.dig(:product_variant, :regular_price)
      permitted = params.require(:product_variant).permit(
        :variant_type, :option_value_1, :option_value_2, :merchandise_condition_id,
        :merchandise_class_id, :tax_class_override_id, :inventory_mode, :pricing_method,
        :target_margin_bps, :supplier_returnable, :regular_price, :regular_price_cents,
        :industry_identifier, :status, :lock_version
      )

      if permitted.key?(:regular_price) || params[:product_variant]&.key?(:regular_price)
        raw = permitted.delete(:regular_price)
        raw = params.dig(:product_variant, :regular_price) if raw.nil?
        begin
          permitted[:regular_price_cents] = Money::ParseCents.call(raw)
        rescue Money::ParseCents::Error => e
          @money_error = e.message
          permitted.delete(:regular_price_cents)
        end
      end

      %i[option_value_1 option_value_2 merchandise_condition_id merchandise_class_id tax_class_override_id
         inventory_mode pricing_method regular_price_cents industry_identifier].each do |key|
        permitted[key] = nil if permitted[key].blank?
      end
      permitted[:status] = permitted[:status].to_s.strip.presence || "active"
      if permitted[:variant_type].to_s == "standard"
        permitted[:merchandise_condition_id] = nil
      end

      # Blank means "use class default" on create: omit the key so DefaultResolver copies.
      # On update, blank margin clears the sticky value; blank supplier_returnable is invalid.
      creating = action_name == "create"
      if permitted[:target_margin_bps].blank?
        if creating
          permitted.delete(:target_margin_bps)
        else
          permitted[:target_margin_bps] = nil
        end
      end
      if creating && permitted[:supplier_returnable].blank?
        permitted.delete(:supplier_returnable)
      elsif permitted.key?(:supplier_returnable) && !permitted[:supplier_returnable].nil?
        permitted[:supplier_returnable] = ActiveModel::Type::Boolean.new.cast(permitted[:supplier_returnable])
      end

      permitted
    end

    def load_purchasing_context
      @can_order_stock = current_store.present? &&
        effective_permissions.include?("orders.manage") &&
        stock_orderable_variant?(@product_variant)
      @can_create_customer_request = current_store.present? &&
        effective_permissions.include?("customer_requests.manage") &&
        customer_requestable_variant?(@product_variant, store: current_store)

      if @product_variant.standard? && @product_variant.inventory_mode == "inventory"
        @supplier_variant_sources = @product_variant.supplier_variant_sources
          .includes(:supplier, :store_supplier_source_preferences)
          .admin_ordered
        @can_manage_supplier_sources = effective_permissions.include?("suppliers.manage")
        if current_store.present?
          @store_source_preference = StoreSupplierSourcePreference.find_by(
            store_id: current_store.id,
            product_variant_id: @product_variant.id
          )
        end
      end

      return unless current_store.present? && @product_variant.standard?

      @preferred_source = Purchasing::PreferredSourceResolver.call(
        store: current_store,
        product_variant: @product_variant
      )
      @available_quantity = Inventory::Availability.available(current_store, @product_variant)
      @reserved_quantity = Inventory::Availability.active_reserved_quantity(current_store, @product_variant)
      @open_stock_order_quantity = Order
        .joins(purchase_order_line: :purchase_order)
        .where(store_id: current_store.id, product_variant_id: @product_variant.id, customer_request_id: nil)
        .where(purchase_orders: { status: %w[draft sent] })
        .sum(:requested_quantity)
      @open_customer_order_quantity = Order
        .joins(purchase_order_line: :purchase_order)
        .where(store_id: current_store.id, product_variant_id: @product_variant.id)
        .where.not(customer_request_id: nil)
        .where(purchase_orders: { status: %w[draft sent] })
        .sum(:requested_quantity)
    end
  end
end
