# frozen_string_literal: true

module Purchasing
  # Scan/search add from a fixed draft PO: always creates stock order + dedicated line.
  class AddStockOrderToDraftPo
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_order:,
      product_variant:,
      actor:,
      quantity: 1,
      notes: nil,
      expected_unit_cost_cents: nil,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @purchase_order = purchase_order
      @product_variant = product_variant
      @actor = actor
      @quantity = quantity
      @notes = notes
      @expected_unit_cost_cents = expected_unit_cost_cents
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      Order.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?
        raise Purchasing::Error, "quantity must be positive" unless @quantity.to_i.positive?

        po = PurchaseOrder.lock.find(@purchase_order.id)
        assert_lock_version!(po)
        raise Purchasing::Error, "purchase order must be draft" unless po.draft?
        raise Purchasing::Error, "generated purchase orders must return to draft before adding lines" if po.generated?

        DraftPoPlacement.assert_standard_orderable!(@product_variant)

        source = SupplierVariantSource.active.find_by(
          supplier_id: po.supplier_id,
          product_variant_id: @product_variant.id
        )
        # Prefer source for this PO's supplier; fall back to preferred for economics only when
        # the preferred source is the same supplier.
        preferred = PreferredSourceResolver.call(store: po.store, product_variant: @product_variant)
        economics_source = source || (preferred if preferred&.supplier_id == po.supplier_id)
        economics = DraftPoPlacement.economics_from(
          source: economics_source,
          expected_unit_cost_cents: @expected_unit_cost_cents
        )

        number = StoreDocumentSequence.next_number!(store: po.store, document_kind: "order")
        order = Order.create!(
          store: po.store,
          number: number,
          product_variant: @product_variant,
          supplier: po.supplier,
          requested_quantity: @quantity.to_i,
          notes: @notes
        )

        line = DraftPoPlacement.create_line!(
          purchase_order: po,
          order: order,
          economics: economics,
          notes: @notes
        )

        Audit::Recorder.record!(
          action: "orders.add_to_draft_po",
          outcome: "succeeded",
          actor_user: @actor,
          store: po.store,
          subject: order,
          correlation_id: @correlation_id,
          after_values: {
            number: order.number,
            purchase_order_id: po.id,
            purchase_order_line_id: line.id,
            product_variant_id: @product_variant.id,
            requested_quantity: order.requested_quantity
          }
        )

        order
      end
    end

    private

    def assert_lock_version!(po)
      return if @expected_lock_version.nil?
      return if po.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(po, "update")
    end
  end
end
