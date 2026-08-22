# frozen_string_literal: true

module Customers
  class CreateRequest
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      customer:,
      product_variant:,
      actor:,
      notes: nil,
      estimated_price_cents: nil,
      supplier: nil,
      expected_unit_cost_cents: nil,
      correlation_id: nil
    )
      @store = store
      @customer = customer
      @product_variant = product_variant
      @actor = actor
      @notes = notes
      @estimated_price_cents = estimated_price_cents
      @supplier = supplier
      @expected_unit_cost_cents = expected_unit_cost_cents
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      CustomerRequest.transaction do
        validate_basics!
        tracking = @product_variant.derived_inventory_tracking

        if tracking == "quantity"
          balance = Inventory::Balances.lock_or_create!(store: @store, product_variant: @product_variant)
          available = Inventory::Availability.available(@store, @product_variant, balance: balance)
          if available.positive?
            create_pending_location_request!
          else
            create_special_order_request!
          end
        else
          units = Inventory::Availability.unreserved_on_hand_units(@store, @product_variant)
          raise Customers::Error, "out-of-stock Used merchandise cannot be requested" unless units.exists?

          create_pending_location_request!
        end
      end
    end

    private

    def validate_basics!
      raise Customers::Error, "store is required" if @store.blank?
      raise Customers::Error, "customer is required" if @customer.blank?
      raise Customers::Error, "customer is inactive" unless @customer.active?
      raise Customers::Error, "product variant is required" if @product_variant.blank?
      raise Customers::Error, "actor is required" if @actor.blank?

      tracking = @product_variant.derived_inventory_tracking
      unless %w[quantity individual].include?(tracking)
        raise Customers::Error, "variant is not inventory-tracked"
      end
    end

    def create_pending_location_request!
      number = StoreDocumentSequence.next_number!(store: @store, document_kind: "customer_request")
      request = CustomerRequest.create!(
        store: @store,
        number: number,
        customer: @customer,
        product_variant: @product_variant,
        requested_quantity: 1,
        estimated_price_cents: @estimated_price_cents,
        notes: @notes,
        status: "pending_location"
      )

      Audit::Recorder.record!(
        action: "customer_requests.create",
        outcome: "succeeded",
        actor_user: @actor,
        store: @store,
        subject: request,
        correlation_id: @correlation_id,
        after_values: {
          number: request.number,
          status: request.status,
          customer_id: @customer.id,
          product_variant_id: @product_variant.id
        }
      )

      request
    end

    def create_special_order_request!
      Purchasing::CreateSpecialOrderFromRequest.call(
        store: @store,
        customer: @customer,
        product_variant: @product_variant,
        actor: @actor,
        notes: @notes,
        estimated_price_cents: @estimated_price_cents,
        supplier: @supplier,
        expected_unit_cost_cents: @expected_unit_cost_cents,
        correlation_id: @correlation_id
      )
    rescue Purchasing::Error => e
      raise Customers::Error, e.message
    end
  end
end
