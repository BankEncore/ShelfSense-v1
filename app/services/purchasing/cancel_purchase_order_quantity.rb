# frozen_string_literal: true

module Purchasing
  class CancelPurchaseOrderQuantity
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_order_line:,
      actor:,
      quantity:,
      source:,
      reason:,
      re_source: false,
      replacement_supplier: nil,
      expected_unit_cost_cents: nil,
      occurred_at: nil,
      correlation_id: nil
    )
      @purchase_order_line = purchase_order_line
      @actor = actor
      @quantity = quantity
      @source = source.to_s
      @reason = reason.to_s.strip
      @re_source = re_source
      @replacement_supplier = replacement_supplier
      @expected_unit_cost_cents = expected_unit_cost_cents
      @occurred_at = occurred_at || Time.current
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      PurchaseOrder.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?
        raise Purchasing::Error, "quantity must be positive" unless @quantity.to_i.positive?
        raise Purchasing::Error, "reason is required" if @reason.blank?
        unless PurchaseOrderLineCancellation::SOURCES.include?(@source)
          raise Purchasing::Error, "cancellation source must be buyer or supplier"
        end

        line = PurchaseOrderLine.lock.find(@purchase_order_line.id)
        po = PurchaseOrder.lock.find(line.purchase_order_id)
        raise Purchasing::Error, "cancellations require a sent purchase order" unless po.sent? || po.closed?

        order = Order.lock.find(line.order_id)
        request = order.customer_request_id.present? ? CustomerRequest.lock.find(order.customer_request_id) : nil
        state = PurchaseOrderLineState.lock.find_by(purchase_order_line_id: line.id)
        raise Purchasing::Error, "line state is missing" if state.blank?

        qty = @quantity.to_i
        open_qty = line.open_quantity
        raise Purchasing::Error, "cancellation quantity exceeds open quantity (#{open_qty})" if qty > open_qty

        cancellation = PurchaseOrderLineCancellation.create!(
          purchase_order_line: line,
          quantity: qty,
          source: @source,
          reason: @reason,
          recorded_by: @actor,
          occurred_at: @occurred_at
        )

        replacement = nil
        if @re_source
          raise Purchasing::Error, "replacement supplier is required to re-source" if @replacement_supplier.blank?
          replacement = create_replacement!(order: order, quantity: qty, request: request)
        end

        line.reload
        ClosePurchaseOrderIfComplete.call!(
          purchase_order: po.reload,
          actor: @actor,
          correlation_id: @correlation_id
        )

        Audit::Recorder.record!(
          action: @re_source ? "purchase_orders.cancel_and_re_source" : "purchase_orders.cancel_quantity",
          outcome: "succeeded",
          actor_user: @actor,
          store: po.store,
          subject: line,
          correlation_id: @correlation_id,
          after_values: {
            purchase_order_id: po.id,
            purchase_order_line_id: line.id,
            cancellation_id: cancellation.id,
            quantity: qty,
            source: @source,
            open_quantity: line.open_quantity,
            replacement_order_id: replacement&.id,
            purchase_order_status: po.reload.status
          }
        )

        Outbox::Recorder.record!(
          event_type: "purchase_order_line.cancelled",
          aggregate: line,
          correlation_id: @correlation_id,
          occurred_at: @occurred_at,
          payload: {
            purchase_order_id: po.id,
            purchase_order_line_id: line.id,
            cancellation_id: cancellation.id,
            quantity: qty,
            source: @source,
            replacement_order_id: replacement&.id
          }
        )

        {
          cancellation: cancellation,
          replacement_order: replacement,
          purchase_order: po.reload
        }
      end
    end

    private

    def create_replacement!(order:, quantity:, request:)
      supplier = @replacement_supplier
      raise Purchasing::Error, "replacement supplier is inactive" unless supplier.active?

      DraftPoPlacement.assert_standard_orderable!(order.product_variant)

      if order.customer_order?
        raise Purchasing::Error, "customer special order cancellation quantity must be 1" unless quantity == 1
        if request.present? && !%w[special_order_pending ordered].include?(request.status)
          raise Purchasing::Error, "customer request is not eligible for re-source"
        end
      end

      source = SupplierVariantSource.active.find_by(
        supplier_id: supplier.id,
        product_variant_id: order.product_variant_id
      )
      economics = DraftPoPlacement.economics_from(
        source: source,
        expected_unit_cost_cents: @expected_unit_cost_cents
      )

      number = StoreDocumentSequence.next_number!(store: order.store, document_kind: "order")
      replacement = Order.create!(
        store: order.store,
        number: number,
        product_variant: order.product_variant,
        supplier: supplier,
        customer_request_id: order.customer_request_id,
        requested_quantity: quantity,
        notes: order.notes,
        replaces_order: order
      )

      draft_po = DraftPoPlacement.find_or_create_open_draft!(store: order.store, supplier: supplier)
      DraftPoPlacement.create_line!(
        purchase_order: draft_po,
        order: replacement,
        economics: economics,
        notes: order.notes
      )

      if request.present? && request.status == "ordered"
        # Replacement is unsent; request returns to special_order_pending until the new PO sends.
        request.update!(status: "special_order_pending")
      end

      replacement
    end
  end
end
