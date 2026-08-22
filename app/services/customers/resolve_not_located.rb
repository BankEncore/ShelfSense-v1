# frozen_string_literal: true

module Customers
  # Resolves a pending_location request when staff cannot find the merchandise.
  # Standard: convert to special order or cancel. Used: cancel only.
  class ResolveNotLocated
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      customer_request:,
      actor:,
      notes: nil,
      convert_to_special_order: false,
      supplier: nil,
      expected_unit_cost_cents: nil,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @request = customer_request
      @actor = actor
      @notes = notes
      @convert_to_special_order = convert_to_special_order
      @supplier = supplier
      @expected_unit_cost_cents = expected_unit_cost_cents
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Customers::Error, "actor is required" if @actor.blank?

      CustomerRequest.transaction do
        request = CustomerRequest.lock.find(@request.id)
        assert_lock_version!(request)
        raise Customers::Error, "request is not pending location" unless request.pending_location?

        if @convert_to_special_order
          if request.product_variant.used?
            raise Customers::Error, "Used requests cannot convert to a special order"
          end

          begin
            Purchasing::CreateSpecialOrderFromRequest.call(
              customer_request: request,
              actor: @actor,
              location_failure_notes: @notes,
              supplier: @supplier,
              expected_unit_cost_cents: @expected_unit_cost_cents,
              expected_lock_version: request.lock_version,
              correlation_id: @correlation_id
            )
          rescue Purchasing::Error => e
            raise Customers::Error, e.message
          end
        else
          request.update!(
            location_failed_at: Time.current,
            location_failed_by: @actor,
            location_failure_notes: @notes
          )

          CancelRequest.call(
            customer_request: request,
            actor: @actor,
            reason: "not located",
            location_failure_notes: @notes,
            expected_lock_version: request.lock_version,
            correlation_id: @correlation_id
          )
        end
      end
    end

    private

    def assert_lock_version!(request)
      return if @expected_lock_version.nil?
      return if request.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(request, "update")
    end
  end
end
