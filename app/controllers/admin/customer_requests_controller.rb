# frozen_string_literal: true

module Admin
  class CustomerRequestsController < BaseController
    before_action -> { require_permission!("customers.view") }, only: %i[index show]
    before_action -> { require_permission!("customer_requests.manage") },
                  only: %i[new create cancel customer_lookup merchandise_lookup]
    before_action :require_store_for_create!, only: %i[new create customer_lookup merchandise_lookup]
    before_action :set_customer_request, only: %i[show cancel]

    def index
      @stores = accessible_stores.order(:name).select do |store|
        Authorization::PermissionEvaluator.allowed?(
          user: current_user,
          permission_key: "customers.view",
          store: store
        )
      end
      scope = CustomerRequest.includes(:customer, { product_variant: :product }, :store)
                             .where(store_id: @stores.map(&:id))
      selected_store_id = params.key?(:store_id) ? permitted_store_filter : current_store&.id
      @index = CustomerRequests::AdminIndexQuery.call(
        scope: scope,
        q: params[:q],
        status: params[:status],
        store_id: selected_store_id,
        store_filter_applied: params[:store_id].present?,
        page: params[:page]
      )
      @customer_requests = @index.records
    end

    def show; end

    def new
      @customer_request = CustomerRequest.new(store: current_store)
      assign_variant_from_params!(
        @customer_request,
        params[:product_variant_id] || params.dig(:customer_request, :product_variant_id)
      )
      customer_id = params[:customer_id] || params.dig(:customer_request, :customer_id)
      if customer_id.present?
        @customer_request.customer = Customer.active.find_by(id: customer_id)
      end
      load_request_form_options
    end

    def customer_lookup
      prepare_lookup_request
      @customer_query = params[:customer_q].to_s.strip
      @customer_results = search_customers(@customer_query) if @customer_query.present?
      render :new
    end

    def merchandise_lookup
      prepare_lookup_request
      @merchandise_query = params[:merchandise_q].to_s.strip
      @merchandise_results = search_merchandise(@merchandise_query) if @merchandise_query.present?
      load_merchandise_availability if @merchandise_results.present?
      render :new
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
    rescue Customers::Error, Money::ParseCents::Error, ActiveRecord::RecordNotFound => e
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

    def permitted_store_filter
      return if params[:store_id].blank?

      @stores.find { |store| store.id == params[:store_id] }&.id
    end

    def prepare_lookup_request
      attributes = request_form_attributes
      customer_id = attributes.delete("customer_id")
      @customer_request = CustomerRequest.new(store: current_store, **attributes)
      @customer_request.customer = Customer.active.find_by(id: customer_id) if customer_id.present?
      assign_variant_from_params!(@customer_request, @customer_request.product_variant_id)
      load_request_form_options
    end

    def request_form_attributes
      params.fetch(:customer_request, {}).permit(:customer_id, :product_variant_id, :notes).to_h
    end

    def search_customers(query)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      Customer.active
              .where(
                "display_name ILIKE :q OR email ILIKE :q OR phone ILIKE :q OR id::text ILIKE :q",
                q: pattern
              )
              .admin_ordered
              .limit(25)
    end

    def search_merchandise(query)
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      identifier = query.gsub(/[\s-]/, "")
      ProductVariant.active
                    .joins(:product)
                    .merge(Product.active)
                    .where(
                      <<~SQL.squish,
                        products.name ILIKE :pattern OR products.lookup_code ILIKE :pattern OR
                        products.primary_identifier = :identifier OR products.industry_identifier = :identifier OR
                        product_variants.sku = :identifier OR product_variants.industry_identifier = :identifier
                      SQL
                      pattern: pattern,
                      identifier: identifier
                    )
                    .includes(:product)
                    .order(Product.arel_table[:name], :variant_type, :sku)
                    .limit(25)
    end

    def load_merchandise_availability
      @availability_by_variant_id = @merchandise_results.to_h do |variant|
        value = if variant.standard?
          Inventory::Availability.available(current_store, variant)
        else
          Inventory::Availability.unreserved_on_hand_units(current_store, variant).count
        end
        [ variant.id, value ]
      end
    end

    def set_customer_request
      @customer_request = CustomerRequest.includes(
        :store,
        :customer,
        :location_failed_by,
        :cancelled_by,
        { product_variant: [ :product, :merchandise_condition ] },
        { customer_request_allocations: [
          :inventory_unit,
          :released_by,
          { purchase_receipt_line: :purchase_receipt },
          { fulfilled_pos_transaction_line: :pos_transaction }
        ] },
        { orders: [
          :supplier,
          :replaces_order,
          :cancelled_by,
          { purchase_order_line: [
            :line_state,
            :cancellations,
            { purchase_receipt_lines: :purchase_receipt },
            :purchase_order
          ] }
        ] }
      ).find(params[:id])
      @allocations = @customer_request.customer_request_allocations.sort_by(&:created_at)
      @related_orders = @customer_request.orders.sort_by(&:created_at)
      @active_allocation = @allocations.find(&:reserved?)
      @unsent_special_orders = @related_orders.select { |order| !order.cancelled? && order.unsent? }
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

      Money::ParseCents.call(value)
    end
  end
end
