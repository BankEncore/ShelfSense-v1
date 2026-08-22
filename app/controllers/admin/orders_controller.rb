# frozen_string_literal: true

module Admin
  class OrdersController < BaseController
    before_action -> { require_permission!("orders.view") }, only: %i[index show]
    before_action -> { require_permission!("orders.manage") }, only: %i[new create]
    before_action :require_store_for_create!, only: %i[new create]
    before_action :set_order, only: :show

    def index
      scope = Order.includes(:product_variant, :supplier, :store, :customer_request).admin_ordered
      scope = scope.for_store(current_store) if current_store.present?
      @orders = scope.limit(200)
    end

    def show
      @line = @order.purchase_order_line
      @purchase_order = @line&.purchase_order
    end

    def new
      @order = Order.new(store: current_store, requested_quantity: 1)
      assign_variant_from_params!(@order, params[:product_variant_id] || params.dig(:order, :product_variant_id))
      load_order_form_options
    end

    def create
      variant = ProductVariant.find(params.require(:order).require(:product_variant_id))
      supplier_id = params.dig(:order, :supplier_id).presence
      supplier = supplier_id ? Supplier.active.find(supplier_id) : nil
      order = Purchasing::CreateStockOrder.call(
        store: current_store,
        product_variant: variant,
        actor: current_user,
        quantity: params.require(:order).require(:requested_quantity),
        supplier: supplier,
        notes: params.dig(:order, :notes),
        expected_unit_cost_cents: optional_cents(params.dig(:order, :expected_unit_cost_cents))
      )
      po = order.purchase_order
      redirect_to ops_purchase_order_path(po),
                  notice: "Stock order ##{order.number} created and added to draft PO."
    rescue Purchasing::Error, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      @order = Order.new(
        store: current_store,
        product_variant_id: params.dig(:order, :product_variant_id),
        supplier_id: params.dig(:order, :supplier_id),
        requested_quantity: params.dig(:order, :requested_quantity) || 1,
        notes: params.dig(:order, :notes)
      )
      assign_variant_from_params!(@order, @order.product_variant_id)
      load_order_form_options
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    private

    def set_order
      @order = Order.find(params[:id])
      return unless authorize!("orders.view", store: @order.store)
    end

    def require_store_for_create!
      return if current_store.present?

      redirect_to new_store_selection_path, alert: "Select a store before creating an order."
    end

    def assign_variant_from_params!(order, variant_id)
      return if variant_id.blank?

      @product_variant = ProductVariant.includes(:product).find_by(id: variant_id)
      order.product_variant = @product_variant if @product_variant
    end

    def load_order_form_options
      @suppliers = Supplier.active.admin_ordered
      return if @product_variant.blank? || current_store.blank?

      @preferred_source = Purchasing::PreferredSourceResolver.call(
        store: current_store,
        product_variant: @product_variant
      )
      @preferred_supplier = @preferred_source&.supplier
      @preferred_expected_cost_cents = @preferred_source&.derived_expected_unit_cost_cents
    end

    def optional_cents(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
