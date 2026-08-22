# frozen_string_literal: true

module Ops
  class LocationsController < BaseController
    before_action -> { require_permission!("customer_requests.locate") }
    before_action :set_customer_request, only: %i[confirm not_located]

    def show
      load_location_queue
    end

    def confirm
      require_physical_confirmation! if @customer_request.product_variant.standard?
      unit = resolve_unit_param
      Customers::ConfirmLocation.call(
        customer_request: @customer_request,
        actor: current_user,
        inventory_unit: unit,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_location_path, notice: "Request ##{@customer_request.number} located and reserved."
    rescue Customers::Error, ActiveRecord::RecordInvalid => e
      render_mutation_failure(:confirm, e, field: @customer_request.product_variant.used? ? :inventory_unit_id : :confirm)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(:confirm, e, field: @customer_request.product_variant.used? ? :inventory_unit_id : :confirm, stale: true)
    end

    def not_located
      convert = ActiveModel::Type::Boolean.new.cast(params[:convert_to_special_order])
      supplier = params[:supplier_id].present? ? Supplier.active.find(params[:supplier_id]) : nil
      Customers::ResolveNotLocated.call(
        customer_request: @customer_request,
        actor: current_user,
        notes: params[:notes],
        convert_to_special_order: convert,
        supplier: supplier,
        expected_unit_cost_cents: optional_cents(params[:expected_unit_cost_cents]),
        expected_lock_version: params[:lock_version]
      )
      notice = if convert
        "Request ##{@customer_request.number} converted to a special order."
      else
        "Request ##{@customer_request.number} cancelled (not located)."
      end
      redirect_to ops_location_path, notice: notice
    rescue Customers::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
      render_mutation_failure(convert ? :special_order : :not_located, e, field: convert ? :expected_unit_cost_cents : :notes)
    rescue ActiveRecord::StaleObjectError => e
      render_mutation_failure(convert ? :special_order : :not_located, e, field: convert ? :expected_unit_cost_cents : :notes, stale: true)
    end

    private

    def load_location_queue
      @pending_requests = CustomerRequest.pending_location
        .for_store(current_store)
        .includes(:customer, product_variant: { product: :merchandise_category })
        .order(:created_at, :id)
      @availability_by_request = @pending_requests.index_with do |customer_request|
        variant = customer_request.product_variant
        if variant.standard?
          Inventory::Availability.available(current_store, variant)
        else
          Inventory::Availability.unreserved_on_hand_units(current_store, variant).count
        end
      end
      @units_by_request = @pending_requests.index_with do |customer_request|
        next [] if customer_request.product_variant.standard?

        Inventory::Availability.unreserved_on_hand_units(current_store, customer_request.product_variant)
          .order(:unit_identifier).to_a
      end
      @suppliers = Supplier.active.admin_ordered.to_a
    end

    def render_mutation_failure(action, exception, field:, stale: false)
      @submitted = params.to_unsafe_h.slice("inventory_unit_id", "unit_identifier", "notes", "supplier_id", "expected_unit_cost_cents")
      @error_action = action
      @error_field = field
      @selected_row_id = @customer_request.id
      @conflict = stale
      @mutation_errors = [ stale ? "This request was changed by someone else." : exception.message ]
      @customer_request.reload
      load_location_queue
      render :show, status: :unprocessable_entity
    end

    def set_customer_request
      @customer_request = CustomerRequest.for_store(current_store).find(params[:id])
    end

    def resolve_unit_param
      return if @customer_request.product_variant.standard?

      unit_id = params[:inventory_unit_id].presence
      identifier = params[:unit_identifier].to_s.strip.presence
      if unit_id.present?
        InventoryUnit.find(unit_id)
      elsif identifier.present?
        InventoryUnit.find_by!(unit_identifier: Identifiers::Normalizer.normalize(identifier, allow_shelfsense_222: false))
      end
    rescue Identifiers::NormalizationError, ActiveRecord::RecordNotFound => e
      raise Customers::Error, e.message
    end

    def require_physical_confirmation!
      return if ActiveModel::Type::Boolean.new.cast(params[:physical_copy_confirmed])

      raise Customers::Error, "Confirm that you physically located a copy before reserving it."
    end

    def optional_cents(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
