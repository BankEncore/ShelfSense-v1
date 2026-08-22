# frozen_string_literal: true

module Ops
  class LocationsController < BaseController
    before_action -> { require_permission!("customer_requests.locate") }
    before_action :set_customer_request, only: %i[confirm not_located]

    def show
      @pending_requests = CustomerRequest.pending_location
        .for_store(current_store)
        .includes(:customer, :product_variant)
        .order(:number)
    end

    def confirm
      unit = resolve_unit_param
      Customers::ConfirmLocation.call(
        customer_request: @customer_request,
        actor: current_user,
        inventory_unit: unit,
        expected_lock_version: params[:lock_version]
      )
      redirect_to ops_location_path, notice: "Request ##{@customer_request.number} located and reserved."
    rescue Customers::Error, ActiveRecord::RecordInvalid => e
      redirect_to ops_location_path, alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_location_path, alert: "This request was changed by someone else. Reload and try again."
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
      redirect_to ops_location_path, alert: e.message
    rescue ActiveRecord::StaleObjectError
      redirect_to ops_location_path, alert: "This request was changed by someone else. Reload and try again."
    end

    private

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

    def optional_cents(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
