# frozen_string_literal: true

module Purchasing
  class CreateStockOrder
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      store:,
      product_variant:,
      actor:,
      quantity:,
      supplier: nil,
      notes: nil,
      expected_unit_cost_cents: nil,
      correlation_id: nil
    )
      @store = store
      @product_variant = product_variant
      @actor = actor
      @quantity = quantity
      @supplier = supplier
      @notes = notes
      @expected_unit_cost_cents = expected_unit_cost_cents
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      Order.transaction do
        raise Purchasing::Error, "store is required" if @store.blank?
        raise Purchasing::Error, "actor is required" if @actor.blank?
        raise Purchasing::Error, "quantity must be positive" unless @quantity.to_i.positive?

        DraftPoPlacement.assert_standard_orderable!(@product_variant)
        supplier, source = DraftPoPlacement.resolve_supplier_and_source(
          store: @store,
          product_variant: @product_variant,
          supplier: @supplier
        )
        economics = DraftPoPlacement.economics_from(
          source: source,
          expected_unit_cost_cents: @expected_unit_cost_cents
        )

        number = StoreDocumentSequence.next_number!(store: @store, document_kind: "order")
        order = Order.create!(
          store: @store,
          number: number,
          product_variant: @product_variant,
          supplier: supplier,
          requested_quantity: @quantity.to_i,
          notes: @notes
        )

        purchase_order = DraftPoPlacement.find_or_create_open_draft!(store: @store, supplier: supplier)
        line = DraftPoPlacement.create_line!(
          purchase_order: purchase_order,
          order: order,
          economics: economics,
          notes: @notes
        )

        Audit::Recorder.record!(
          action: "orders.create_stock",
          outcome: "succeeded",
          actor_user: @actor,
          store: @store,
          subject: order,
          correlation_id: @correlation_id,
          after_values: {
            number: order.number,
            supplier_id: supplier.id,
            product_variant_id: @product_variant.id,
            requested_quantity: order.requested_quantity,
            purchase_order_id: purchase_order.id,
            purchase_order_line_id: line.id
          }
        )

        order
      end
    end
  end
end
