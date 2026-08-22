# frozen_string_literal: true

module Customers
  class FulfillPickup
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(allocation:, pos_transaction_line:, actor:, correlation_id: nil)
      @allocation = allocation
      @line = pos_transaction_line
      @actor = actor
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      unless InventoryLedgerEntry.connection.transaction_open?
        raise Customers::Error, "FulfillPickup must run inside the caller's transaction"
      end

      allocation = CustomerRequestAllocation.lock.find(@allocation.id)
      raise Customers::Error, "allocation is not reserved for pickup" unless allocation.reserved?
      if allocation.id != @line.customer_request_allocation_id
        raise Customers::Error, "allocation does not match the POS line"
      end
      if allocation.used_unit? && allocation.inventory_unit_id != @line.inventory_unit_id
        raise Customers::Error, "inventory unit does not match the allocation"
      end

      request = CustomerRequest.lock.find(allocation.customer_request_id)
      raise Customers::Error, "customer request is not available for pickup" unless request.available?

      allocation.update!(
        status: "fulfilled",
        fulfilled_pos_transaction_line: @line
      )
      request.update!(
        status: "completed",
        completed_at: Time.current
      )

      Audit::Recorder.record!(
        action: "customer_requests.pickup_completed",
        outcome: "succeeded",
        actor_user: @actor,
        store: request.store,
        subject: request,
        correlation_id: @correlation_id,
        after_values: {
          status: request.status,
          allocation_id: allocation.id,
          pos_transaction_line_id: @line.id,
          pos_transaction_id: @line.pos_transaction_id
        }
      )

      Outbox::Recorder.record!(
        event_type: "customer.request_completed",
        aggregate: request,
        correlation_id: @correlation_id,
        occurred_at: Time.current,
        payload: {
          customer_request_id: request.id,
          allocation_id: allocation.id,
          pos_transaction_id: @line.pos_transaction_id,
          pos_transaction_line_id: @line.id,
          store_id: request.store_id
        }
      )

      request
    end
  end
end
