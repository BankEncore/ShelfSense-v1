# frozen_string_literal: true

module Customers
  class CancelRequest
    DRAFT_ORDER_DECISION_REQUIRED =
      "This request has an unsent special order. Pass cancel_draft_order: true or false."

    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      customer_request:,
      actor:,
      reason:,
      cancel_draft_order: nil,
      expected_lock_version: nil,
      location_failure_notes: nil,
      correlation_id: nil
    )
      @request = customer_request
      @actor = actor
      @reason = reason.to_s.strip
      @cancel_draft_order = cancel_draft_order
      @expected_lock_version = expected_lock_version
      @location_failure_notes = location_failure_notes
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      CustomerRequest.transaction do
        raise Customers::Error, "actor is required" if @actor.blank?
        raise Customers::Error, "cancellation reason is required" if @reason.blank?

        # Soft-read for draft-order decisions and reservation targets. Do not hold
        # customer_request across inventory acquisition.
        peek = CustomerRequest.find(@request.id)
        raise Customers::Error, "request is already cancelled" if peek.cancelled?
        raise Customers::Error, "completed requests cannot be cancelled" if peek.completed?

        unsent_orders = unsent_orders_for(peek)
        if unsent_orders.any?
          if @cancel_draft_order.nil?
            raise Customers::Error, DRAFT_ORDER_DECISION_REQUIRED
          end
          # Draft Order/PO locks before inventory kernel.
          cancel_unsent_orders!(unsent_orders) if @cancel_draft_order
        end

        allocation_peek = peek.customer_request_allocations.reserved.first
        allocation = nil

        if allocation_peek
          # Lock order: InventoryBalance → InventoryUnit (Used) → customer_request → allocation
          store = peek.store
          variant = peek.product_variant
          Inventory::Balances.lock_or_create!(store: store, product_variant: variant)
          if allocation_peek.used_unit?
            InventoryUnit.lock.find(allocation_peek.inventory_unit_id)
          end

          request = CustomerRequest.lock.find(@request.id)
          assert_lock_version!(request)
          raise Customers::Error, "request is already cancelled" if request.cancelled?
          raise Customers::Error, "completed requests cannot be cancelled" if request.completed?

          allocation = CustomerRequestAllocation.lock.find(allocation_peek.id)
          unless allocation.reserved? && allocation.customer_request_id == request.id
            allocation = nil
          else
            allocation.update!(
              status: "released",
              released_at: Time.current,
              released_by: @actor,
              release_reason: @reason
            )
          end
        else
          request = CustomerRequest.lock.find(@request.id)
          assert_lock_version!(request)
          raise Customers::Error, "request is already cancelled" if request.cancelled?
          raise Customers::Error, "completed requests cannot be cancelled" if request.completed?
        end

        attrs = {
          status: "cancelled",
          cancelled_at: Time.current,
          cancelled_by: @actor,
          cancellation_reason: @reason
        }
        if @location_failure_notes.present? || request.location_failed_at.present?
          attrs[:location_failed_at] ||= Time.current
          attrs[:location_failed_by] ||= @actor
          attrs[:location_failure_notes] = @location_failure_notes.presence || request.location_failure_notes
        end

        request.update!(attrs)

        Audit::Recorder.record!(
          action: "customer_requests.cancel",
          outcome: "succeeded",
          actor_user: @actor,
          store: request.store,
          subject: request,
          correlation_id: @correlation_id,
          after_values: {
            status: request.status,
            cancellation_reason: request.cancellation_reason,
            allocation_released: allocation.present?,
            cancel_draft_order: @cancel_draft_order,
            unsent_orders_cancelled: unsent_orders.any? && @cancel_draft_order
          }
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

    def unsent_orders_for(request)
      Order.active
        .where(customer_request_id: request.id)
        .includes(purchase_order_line: :purchase_order)
        .select { |order| order.unsent? }
    end

    def cancel_unsent_orders!(orders)
      orders.each do |order|
        locked = Order.lock.find(order.id)
        next if locked.cancelled?

        line = locked.purchase_order_line
        po = line&.purchase_order
        po&.lock!

        locked.update!(
          cancelled_at: Time.current,
          cancelled_by: @actor,
          cancellation_reason: @reason
        )

        if line
          line.destroy!
          Purchasing::DraftPoPlacement.destroy_if_empty_draft!(po) if po
        end

        Audit::Recorder.record!(
          action: "orders.cancel_draft",
          outcome: "succeeded",
          actor_user: @actor,
          store: locked.store,
          subject: locked,
          correlation_id: @correlation_id,
          after_values: {
            number: locked.number,
            cancellation_reason: locked.cancellation_reason,
            customer_request_id: locked.customer_request_id
          }
        )
      end
    end
  end
end
