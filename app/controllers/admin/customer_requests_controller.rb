# frozen_string_literal: true

module Admin
  class CustomerRequestsController < BaseController
    before_action -> { require_permission!("customers.view") }, only: %i[index show]
    before_action -> { require_permission!("customer_requests.manage") }, only: %i[new create cancel]
    before_action :require_store_for_create!, only: %i[new create]
    before_action :set_customer_request, only: %i[show cancel]

    def index
      scope = CustomerRequest.includes(:customer, :product_variant, :store).admin_ordered
      scope = scope.for_store(current_store) if current_store.present?
      @customer_requests = scope.limit(200)
    end

    def show; end

    def new
      @customer_request = CustomerRequest.new(store: current_store)
      assign_variant_from_params!(
        @customer_request,
        params[:product_variant_id] || params.dig(:customer_request, :product_variant_id)
      )
      if params[:customer_id].present?
        @customer_request.customer = Customer.active.find_by(id: params[:customer_id])
      end
      load_request_form_options
    end

    def create
      customer = Customer.active.find(params.require(:customer_request).require(:customer_id))
      variant = ProductVariant.find(params.require(:customer_request).require(:product_variant_id))
      supplier_id = params.dig(:customer_request, :supplier_id).presence
      supplier = supplier_id ? Supplier.active.find(supplier_id) : nil
      request = Customers::CreateRequest.call(
        store: current_store,
        customer: customer,
        product_variant: variant,
        actor: current_user,
        notes: params.dig(:customer_request, :notes),
        estimated_price_cents: optional_cents(params.dig(:customer_request, :estimated_price_cents)),
        supplier: supplier,
        expected_unit_cost_cents: optional_cents(params.dig(:customer_request, :expected_unit_cost_cents))
      )
      notice =
        if request.pending_location?
          "Customer request ##{request.number} created — locate in the location queue."
        elsif request.special_order_pending?
          "Customer request ##{request.number} created as a special order on the draft PO."
        else
          "Customer request ##{request.number} created."
        end
      redirect_to admin_customer_request_path(request), notice: notice
    rescue Customers::Error, ActiveRecord::RecordNotFound => e
      @customer_request = CustomerRequest.new(
        store: current_store,
        customer_id: params.dig(:customer_request, :customer_id),
        product_variant_id: params.dig(:customer_request, :product_variant_id),
        notes: params.dig(:customer_request, :notes)
      )
      assign_variant_from_params!(@customer_request, @customer_request.product_variant_id)
      load_request_form_options
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity
    end

    def cancel
      cancel_draft = if params.key?(:cancel_draft_order)
        ActiveModel::Type::Boolean.new.cast(params[:cancel_draft_order])
      end
      Customers::CancelRequest.call(
        customer_request: @customer_request,
        actor: current_user,
        reason: params.require(:cancellation_reason),
        cancel_draft_order: cancel_draft,
        expected_lock_version: params[:lock_version]
      )
      redirect_to admin_customer_request_path(@customer_request), notice: "Customer request cancelled."
    rescue Customers::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_customer_request_path(@customer_request), alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to admin_customer_request_path(@customer_request),
                  alert: "This request was changed by someone else. Reload and try again."
    end

    private

    def set_customer_request
      @customer_request = CustomerRequest.find(params[:id])
      permission = action_name == "cancel" ? "customer_requests.manage" : "customers.view"
      nil unless authorize!(permission, store: @customer_request.store)
    end

    def require_store_for_create!
      return if current_store.present?

      redirect_to new_store_selection_path, alert: "Select a store before creating a customer request."
    end

    def assign_variant_from_params!(request, variant_id)
      return if variant_id.blank?

      @product_variant = ProductVariant.includes(:product).find_by(id: variant_id)
      request.product_variant = @product_variant if @product_variant
    end

    def load_request_form_options
      @customers = Customer.active.admin_ordered
      @suppliers = Supplier.active.admin_ordered
      return if @product_variant.blank? || current_store.blank?

      @preferred_source = Purchasing::PreferredSourceResolver.call(
        store: current_store,
        product_variant: @product_variant
      )
      @available_quantity =
        if @product_variant.standard?
          Inventory::Availability.available(current_store, @product_variant)
        else
          Inventory::Availability.unreserved_on_hand_units(current_store, @product_variant).count
        end
    end

    def optional_cents(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
