# frozen_string_literal: true

module Purchasing
  # Closes a sent PO when every line's open quantity is zero.
  module ClosePurchaseOrderIfComplete
    module_function

    def call!(purchase_order:, actor:, correlation_id: nil)
      po = purchase_order
      return po unless po.sent?

      lines = PurchaseOrderLine.where(purchase_order_id: po.id).includes(:cancellations).to_a
      return po unless lines.all? { |line| line.open_quantity.zero? }

      po.update!(status: "closed", closed_at: Time.current)

      Audit::Recorder.record!(
        action: "purchase_orders.auto_close",
        outcome: "succeeded",
        actor_user: actor,
        store: po.store,
        subject: po,
        correlation_id: correlation_id || SecureRandom.uuid_v7,
        after_values: {
          number: po.number,
          status: po.status,
          closed_at: po.closed_at
        }
      )

      Outbox::Recorder.record!(
        event_type: "purchase_order.closed",
        aggregate: po,
        correlation_id: correlation_id,
        payload: {
          purchase_order_id: po.id,
          store_id: po.store_id,
          supplier_id: po.supplier_id,
          number: po.number,
          closed_at: po.closed_at
        }
      )

      po
    end
  end
end
