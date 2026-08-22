# frozen_string_literal: true

module Customers
  class CancelRequest
    DRAFT_ORDER_DECISION_REQUIRED =
      "This request has an unsent special order. Pass cancel_draft_order: true or false."
    SENT_PO_CONFLICT =
      "cannot cancel draft order because purchase order was already sent"

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

        # Soft-read for draft-order decisions. Do not hold customer_request across inventory acquisition.
        peek = CustomerRequest.find(@request.id)
        raise Customers::Error, "request is already cancelled" if peek.cancelled?
        raise Customers::Error, "completed requests cannot be cancelled" if peek.completed?

        active_orders = active_orders_for(peek)
        unsent_orders = active_orders.select(&:unsent?)
        if @cancel_draft_order == true
          cancel_draft_orders!(active_orders) if active_orders.any?
        elsif unsent_orders.any?
          if @cancel_draft_order.nil?
            raise Customers::Error, DRAFT_ORDER_DECISION_REQUIRED
          end
          # cancel_draft_order: false leaves unsent draft orders on the PO.
        end

        store = peek.store
        variant = peek.product_variant
        # Always serialize on inventory before request so concurrent locate/receipt cannot
        # attach a reserved allocation to a request that is about to be cancelled.
        Inventory::Balances.lock_or_create!(store: store, product_variant: variant)

        request = CustomerRequest.lock.find(@request.id)
        assert_lock_version!(request)
        raise Customers::Error, "request is already cancelled" if request.cancelled?
        raise Customers::Error, "completed requests cannot be cancelled" if request.completed?

        allocation = CustomerRequestAllocation.lock.find_by(
          customer_request_id: request.id,
          status: "reserved"
        )
        if allocation&.used_unit?
          InventoryUnit.lock.find(allocation.inventory_unit_id)
        end

        if allocation&.reserved?
          allocation.update!(
            status: "released",
            released_at: Time.current,
            released_by: @actor,
            release_reason: @reason
          )
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
            draft_orders_cancelled: @cancel_draft_order == true && active_orders.any?
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

    def active_orders_for(request)
      Order.active
        .where(customer_request_id: request.id)
        .includes(purchase_order_line: :purchase_order)
        .to_a
    end

    def cancel_draft_orders!(orders)
      orders.each do |order|
        line = order.purchase_order_line
        if line
          po = PurchaseOrder.lock.find(line.purchase_order_id)
          if po.sent_at.present? || !po.draft?
            raise Customers::Error, SENT_PO_CONFLICT
          end

          locked_order = Order.lock.find(order.id)
          next if locked_order.cancelled?

          line = PurchaseOrderLine.lock.find(line.id)
          raise Customers::Error, "order line changed concurrently" unless line.order_id == locked_order.id

          locked_order.update!(
            cancelled_at: Time.current,
            cancelled_by: @actor,
            cancellation_reason: @reason
          )

          line.destroy!
          Purchasing::DraftPoPlacement.destroy_if_empty_draft!(po)
        else
          locked_order = Order.lock.find(order.id)
          next if locked_order.cancelled?

          locked_order.update!(
            cancelled_at: Time.current,
            cancelled_by: @actor,
            cancellation_reason: @reason
          )
        end

        Audit::Recorder.record!(
          action: "orders.cancel_draft",
          outcome: "succeeded",
          actor_user: @actor,
          store: locked_order.store,
          subject: locked_order,
          correlation_id: @correlation_id,
          after_values: {
            number: locked_order.number,
            cancellation_reason: locked_order.cancellation_reason,
            customer_request_id: locked_order.customer_request_id
          }
        )
      end
    end
  end
end
