# frozen_string_literal: true

module Purchasing
  class ReturnPurchaseOrderToDraft
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(purchase_order:, actor:, expected_lock_version: nil, correlation_id: nil)
      @purchase_order = purchase_order
      @actor = actor
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      PurchaseOrder.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?

        po = PurchaseOrder.lock.find(@purchase_order.id)
        assert_lock_version!(po)
        raise Purchasing::Error, "only draft purchase orders can return to draft" unless po.draft?
        raise Purchasing::Error, "purchase order was already sent" if po.sent_at.present?
        raise Purchasing::Error, "purchase order has not been generated" if po.generated_at.blank?

        line_ids = po.purchase_order_lines.pluck(:id)
        if PurchaseOrderLineState.where(purchase_order_line_id: line_ids).exists?
          raise Purchasing::Error, "cannot return to draft after supplier responses are recorded"
        end
        if PurchaseOrderLineCancellation.where(purchase_order_line_id: line_ids).exists?
          raise Purchasing::Error, "cannot return to draft after cancellations are recorded"
        end
        # Receipts arrive in Slice 7.5; guard when the association exists.
        if po.respond_to?(:purchase_receipts) && po.purchase_receipts.exists?
          raise Purchasing::Error, "cannot return to draft after receiving activity"
        end

        before = { generated_at: po.generated_at, generated_by_id: po.generated_by_id, number: po.number }
        po.update!(generated_at: nil, generated_by: nil)

        Audit::Recorder.record!(
          action: "purchase_orders.return_to_draft",
          outcome: "succeeded",
          actor_user: @actor,
          store: po.store,
          subject: po,
          correlation_id: @correlation_id,
          before_values: before,
          after_values: {
            number: po.number,
            document_revision: po.document_revision,
            generated_at: nil
          }
        )

        po
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
