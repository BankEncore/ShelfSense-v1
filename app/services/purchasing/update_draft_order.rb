# frozen_string_literal: true

module Purchasing
  class UpdateDraftOrder
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      order:,
      actor:,
      quantity: nil,
      supplier: nil,
      notes: :__omit__,
      expected_unit_cost_cents: nil,
      pricing_method_snapshot: :__omit__,
      supplier_list_price_cents_snapshot: :__omit__,
      discount_basis_points_snapshot: :__omit__,
      supplier_item_number_snapshot: :__omit__,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @order = order
      @actor = actor
      @quantity = quantity
      @supplier = supplier
      @notes = notes
      @expected_unit_cost_cents = expected_unit_cost_cents
      @pricing_method_snapshot = pricing_method_snapshot
      @supplier_list_price_cents_snapshot = supplier_list_price_cents_snapshot
      @discount_basis_points_snapshot = discount_basis_points_snapshot
      @supplier_item_number_snapshot = supplier_item_number_snapshot
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      Order.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?

        order = Order.lock.find(@order.id)
        assert_lock_version!(order)
        raise Purchasing::Error, "cancelled orders cannot be edited" if order.cancelled?

        line = order.purchase_order_line
        raise Purchasing::Error, "order has no purchase order line" if line.blank?

        po = PurchaseOrder.lock.find(line.purchase_order_id)
        raise Purchasing::Error, "only unsent draft orders can be edited" unless po.draft?
        raise Purchasing::Error, "generated purchase orders must return to draft before editing" if po.generated?

        before = snapshot(order, line)

        apply_order_updates!(order)
        apply_line_updates!(line, order)

        if @supplier.present? && @supplier.id != order.supplier_id
          move_to_supplier!(order, line, po, @supplier)
        else
          line.save!
          order.save!
          po.touch
        end

        Audit::Recorder.record!(
          action: "orders.update_draft",
          outcome: "succeeded",
          actor_user: @actor,
          store: order.store,
          subject: order,
          correlation_id: @correlation_id,
          before_values: before,
          after_values: snapshot(order.reload, order.purchase_order_line)
        )

        order
      end
    end

    private

    def assert_lock_version!(order)
      return if @expected_lock_version.nil?
      return if order.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(order, "update")
    end

    def apply_order_updates!(order)
      if @quantity.present?
        qty = @quantity.to_i
        raise Purchasing::Error, "quantity must be positive" unless qty.positive?
        if order.customer_order? && qty != 1
          raise Purchasing::Error, "customer special order quantity must remain 1"
        end
        order.requested_quantity = qty
      end
      order.notes = @notes unless @notes == :__omit__
    end

    def apply_line_updates!(line, order)
      line.ordered_quantity = order.requested_quantity
      line.notes_snapshot = order.notes
      unless @expected_unit_cost_cents.nil?
        cost = @expected_unit_cost_cents.to_i
        raise Purchasing::Error, "expected unit cost must be nonnegative" if cost.negative?

        line.expected_unit_cost_cents_snapshot = cost
      end
      unless @pricing_method_snapshot == :__omit__
        line.pricing_method_snapshot = @pricing_method_snapshot
      end
      unless @supplier_list_price_cents_snapshot == :__omit__
        line.supplier_list_price_cents_snapshot = @supplier_list_price_cents_snapshot
      end
      unless @discount_basis_points_snapshot == :__omit__
        line.discount_basis_points_snapshot = @discount_basis_points_snapshot
      end
      unless @supplier_item_number_snapshot == :__omit__
        line.supplier_item_number_snapshot = @supplier_item_number_snapshot
      end
    end

    def move_to_supplier!(order, line, old_po, supplier)
      raise Purchasing::Error, "supplier is inactive" unless supplier.active?

      new_po = DraftPoPlacement.find_or_create_open_draft!(store: order.store, supplier: supplier)
      new_po.lock! if new_po.id != old_po.id

      source = SupplierVariantSource.active.find_by(
        supplier_id: supplier.id,
        product_variant_id: order.product_variant_id
      )
      if source.present? && @expected_unit_cost_cents.nil?
        economics = DraftPoPlacement.economics_from(source: source, expected_unit_cost_cents: nil)
        line.assign_attributes(economics.except(:expected_unit_cost_cents_snapshot).merge(
          expected_unit_cost_cents_snapshot: economics[:expected_unit_cost_cents_snapshot]
        ))
      end

      order.supplier = supplier
      line.purchase_order = new_po
      order.save!
      line.save!
      old_po.touch if old_po.id != new_po.id
      new_po.touch
    end

    def snapshot(order, line)
      {
        supplier_id: order.supplier_id,
        requested_quantity: order.requested_quantity,
        notes: order.notes,
        purchase_order_id: line&.purchase_order_id,
        expected_unit_cost_cents_snapshot: line&.expected_unit_cost_cents_snapshot
      }
    end
  end
end
