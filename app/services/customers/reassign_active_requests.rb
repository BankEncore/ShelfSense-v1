# frozen_string_literal: true

module Customers
  # Reassigns active customer requests from a merge source onto the survivor.
  # Completed and cancelled requests retain their original customer_id (ADR-023).
  class ReassignActiveRequests
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(source:, survivor:)
      @source = source
      @survivor = survivor
    end

    def call
      CustomerRequest.where(
        customer_id: @source.id,
        status: CustomerRequest::ACTIVE_STATUSES
      ).update_all(customer_id: @survivor.id, updated_at: Time.current)
    end
  end
end
