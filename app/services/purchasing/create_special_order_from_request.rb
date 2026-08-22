# frozen_string_literal: true

module Purchasing
  # Creates a Standard customer special order (request status special_order_pending +
  # order + dedicated draft PO line) atomically. Used for OOS create and not-located convert.
  class CreateSpecialOrderFromRequest
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      actor:,
      customer_request: nil,
      store: nil,
      customer: nil,
      product_variant: nil,
      notes: nil,
      estimated_price_cents: nil,
      supplier: nil,
      expected_unit_cost_cents: nil,
      location_failure_notes: nil,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @actor = actor
      @customer_request = customer_request
      @store = store
      @customer = customer
      @product_variant = product_variant
      @notes = notes
      @estimated_price_cents = estimated_price_cents
      @supplier = supplier
      @expected_unit_cost_cents = expected_unit_cost_cents
      @location_failure_notes = location_failure_notes
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      Order.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?

        request = prepare_request!
        DraftPoPlacement.assert_standard_orderable!(request.product_variant)

        supplier, source = DraftPoPlacement.resolve_supplier_and_source(
          store: request.store,
          product_variant: request.product_variant,
          supplier: @supplier
        )
        economics = DraftPoPlacement.economics_from(
          source: source,
          expected_unit_cost_cents: @expected_unit_cost_cents
        )

        number = StoreDocumentSequence.next_number!(store: request.store, document_kind: "order")
        order = Order.create!(
          store: request.store,
          number: number,
          product_variant: request.product_variant,
          supplier: supplier,
          customer_request: request,
          requested_quantity: 1,
          notes: @notes.presence || request.notes
        )

        purchase_order = DraftPoPlacement.find_or_create_open_draft!(
          store: request.store,
          supplier: supplier
        )
        line = DraftPoPlacement.create_line!(
          purchase_order: purchase_order,
          order: order,
          economics: economics,
          notes: order.notes
        )

        Audit::Recorder.record!(
          action: "orders.create_special",
          outcome: "succeeded",
          actor_user: @actor,
          store: request.store,
          subject: order,
          correlation_id: @correlation_id,
          after_values: {
            number: order.number,
            customer_request_id: request.id,
            customer_request_number: request.number,
            request_status: request.status,
            supplier_id: supplier.id,
            purchase_order_id: purchase_order.id,
            purchase_order_line_id: line.id
          }
        )

        request
      end
    end

    private

    def prepare_request!
      if @customer_request.present?
        convert_existing_request!
      else
        create_oos_request!
      end
    end

    def convert_existing_request!
      request = CustomerRequest.lock.find(@customer_request.id)
      assert_lock_version!(request)
      raise Purchasing::Error, "request is not pending location" unless request.pending_location?
      raise Purchasing::Error, "Used requests cannot convert to a special order" if request.product_variant.used?

      attrs = {
        status: "special_order_pending",
        location_failed_at: Time.current,
        location_failed_by: @actor
      }
      attrs[:location_failure_notes] = @location_failure_notes if @location_failure_notes.present?
      request.update!(attrs)
      request
    end

    def create_oos_request!
      raise Purchasing::Error, "store is required" if @store.blank?
      raise Purchasing::Error, "customer is required" if @customer.blank?
      raise Purchasing::Error, "customer is inactive" unless @customer.active?
      raise Purchasing::Error, "product variant is required" if @product_variant.blank?
      raise Purchasing::Error, "Used variants cannot be special-ordered" if @product_variant.used?

      DraftPoPlacement.assert_standard_orderable!(@product_variant)

      balance = Inventory::Balances.lock_or_create!(store: @store, product_variant: @product_variant)
      available = Inventory::Availability.available(@store, @product_variant, balance: balance)
      raise Purchasing::Error, "variant has available stock; use location routing" if available.positive?

      number = StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request")
      CustomerRequest.create!(
        store: @store,
        number: number,
        customer: @customer,
        product_variant: @product_variant,
        requested_quantity: 1,
        estimated_price_cents: @estimated_price_cents,
        notes: @notes,
        status: "special_order_pending"
      )
    end

    def assert_lock_version!(request)
      return if @expected_lock_version.nil?
      return if request.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(request, "update")
    end
  end
end
