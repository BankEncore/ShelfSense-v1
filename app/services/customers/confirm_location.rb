# frozen_string_literal: true

module Customers
  class ConfirmLocation
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(customer_request:, actor:, inventory_unit: nil, expected_lock_version: nil, correlation_id: nil)
      @request = customer_request
      @actor = actor
      @inventory_unit = inventory_unit
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      CustomerRequest.transaction do
        raise Customers::Error, "actor is required" if @actor.blank?

        variant = @request.product_variant
        store = @request.store
        tracking = variant.derived_inventory_tracking

        # Lock order: InventoryBalance → InventoryUnit (Used) → customer_request → allocation
        balance = Inventory::Balances.lock_or_create!(store: store, product_variant: variant)
        unit = lock_used_unit!(store, variant) if tracking == "individual"

        request = CustomerRequest.lock.find(@request.id)
        assert_lock_version!(request)
        raise Customers::Error, "request is not pending location" unless request.pending_location?

        allocation =
          if tracking == "quantity"
            confirm_standard!(request, store, variant, balance)
          else
            confirm_used!(request, unit)
          end

        request.update!(status: "available")

        Audit::Recorder.record!(
          action: "customer_requests.location_confirmed",
          outcome: "succeeded",
          actor_user: @actor,
          store: store,
          subject: request,
          correlation_id: @correlation_id,
          after_values: {
            status: request.status,
            allocation_id: allocation.id,
            allocation_type: allocation.allocation_type,
            inventory_unit_id: allocation.inventory_unit_id
          }.compact
        )

        request
      end
    end

    private

    def assert_lock_version!(request)
      return if @expected_lock_version.nil?
      return if request.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(request, "update")
    end

    def lock_used_unit!(store, variant)
      raise Customers::Error, "inventory unit is required for Used locate" if @inventory_unit.blank?

      unit = InventoryUnit.lock.find(@inventory_unit.id)
      raise Customers::Error, "unit must be on hand" unless unit.on_hand?
      raise Customers::Error, "unit store mismatch" unless unit.store_id == store.id
      raise Customers::Error, "unit variant mismatch" unless unit.product_variant_id == variant.id
      if Inventory::Availability.unit_allocated?(unit)
        raise Customers::Error, "inventory unit is already reserved"
      end

      unit
    rescue ActiveRecord::RecordNotFound
      raise Customers::Error, "inventory unit not found"
    end

    def confirm_standard!(request, store, variant, balance)
      available = Inventory::Availability.available(store, variant, balance: balance)
      raise Customers::Error, "no available quantity to reserve" unless available.positive?

      CustomerRequestAllocation.create!(
        customer_request: request,
        allocation_type: "standard_quantity",
        quantity: 1,
        status: "reserved"
      )
    end

    def confirm_used!(request, unit)
      CustomerRequestAllocation.create!(
        customer_request: request,
        allocation_type: "used_unit",
        inventory_unit: unit,
        quantity: 1,
        status: "reserved"
      )
    end
  end
end
