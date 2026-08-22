# frozen_string_literal: true

module Purchasing
  class AddPurchaseReceiptLine
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt:,
      purchase_order_line:,
      actor:,
      received_quantity:,
      actual_unit_cost_cents:,
      notes: nil,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @receipt = purchase_receipt
      @po_line = purchase_order_line
      @actor = actor
      @received_quantity = received_quantity.to_i
      @actual_unit_cost_cents = actual_unit_cost_cents
      @notes = notes
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "received quantity must be positive" unless @received_quantity.positive?
      if @actual_unit_cost_cents.nil? || @actual_unit_cost_cents.to_i.negative?
        raise Purchasing::Error, "actual unit cost is required and must be nonnegative"
      end

      PurchaseReceipt.transaction do
        receipt = PurchaseReceipt.lock.find(@receipt.id)
        assert_lock_version!(receipt)
        raise Purchasing::Error, "only draft receipts can be edited" unless receipt.draft?

        po = PurchaseOrder.find(@po_line.purchase_order_id)
        raise Purchasing::Error, "PO line store must match the receipt store" unless po.store_id == receipt.store_id
        raise Purchasing::Error, "PO line supplier must match the receipt supplier" unless po.supplier_id == receipt.supplier_id
        raise Purchasing::Error, "purchase order must be sent or closed" unless po.sent? || po.closed?

        line = receipt.purchase_receipt_lines.find_or_initialize_by(purchase_order_line_id: @po_line.id)
        line.assign_attributes(
          product_variant_id: @po_line.product_variant_id,
          received_quantity: @received_quantity,
          # Provisional until post: treat full received qty as unplanned.
          matched_quantity: 0,
          unplanned_quantity: @received_quantity,
          actual_unit_cost_cents: @actual_unit_cost_cents.to_i,
          notes: @notes
        )
        line.save!

        receipt.touch

        Audit::Recorder.record!(
          action: "purchase_receipts.add_line",
          outcome: "succeeded",
          actor_user: @actor,
          store: receipt.store,
          subject: receipt,
          correlation_id: @correlation_id,
          after_values: {
            purchase_receipt_line_id: line.id,
            purchase_order_line_id: @po_line.id,
            received_quantity: line.received_quantity,
            actual_unit_cost_cents: line.actual_unit_cost_cents
          }
        )

        line
      end
    end

    private

    def assert_lock_version!(receipt)
      return if @expected_lock_version.nil?
      return if receipt.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(receipt, "update")
    end
  end
end
