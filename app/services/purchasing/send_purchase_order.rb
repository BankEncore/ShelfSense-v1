# frozen_string_literal: true

module Purchasing
  class SendPurchaseOrder
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_order:,
      actor:,
      transmission_method:,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @purchase_order = purchase_order
      @actor = actor
      @transmission_method = transmission_method.to_s.strip
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      PurchaseOrder.transaction do
        raise Purchasing::Error, "actor is required" if @actor.blank?
        raise Purchasing::Error, "transmission method is required" if @transmission_method.blank?
        unless PurchaseOrder::TRANSMISSION_METHODS.include?(@transmission_method)
          raise Purchasing::Error, "transmission method is invalid"
        end

        po = PurchaseOrder.lock.find(@purchase_order.id)
        assert_lock_version!(po)
        raise Purchasing::Error, "only draft purchase orders can be sent" unless po.draft?
        raise Purchasing::Error, "purchase order must be generated before send" if po.number.blank?
        raise Purchasing::Error, "purchase order must be generated before send" if po.generated_at.blank?
        raise Purchasing::Error, "purchase order was already sent" if po.sent_at.present?

        lines = po.purchase_order_lines.includes(:order, :product_variant, order: :customer_request).to_a
        raise Purchasing::Error, "purchase order has no lines" if lines.empty?
        validate_lines!(lines)

        sent_at = Time.current
        po.update!(
          status: "sent",
          sent_at: sent_at,
          sent_by: @actor,
          transmission_method: @transmission_method
        )

        lines.each do |line|
          PurchaseOrderLineState.create!(
            purchase_order_line: line,
            backordered_quantity: 0
          )

          request = line.order.customer_request
          next if request.blank?
          next unless request.special_order_pending?

          request.lock!
          request.update!(status: "ordered") if request.special_order_pending?
        end

        Audit::Recorder.record!(
          action: "purchase_orders.send",
          outcome: "succeeded",
          actor_user: @actor,
          store: po.store,
          subject: po,
          correlation_id: @correlation_id,
          after_values: {
            number: po.number,
            document_revision: po.document_revision,
            transmission_method: po.transmission_method,
            sent_at: po.sent_at,
            line_count: lines.size
          }
        )

        Outbox::Recorder.record!(
          event_type: "purchase_order.sent",
          aggregate: po,
          correlation_id: @correlation_id,
          occurred_at: sent_at,
          payload: {
            purchase_order_id: po.id,
            store_id: po.store_id,
            supplier_id: po.supplier_id,
            number: po.number,
            document_revision: po.document_revision,
            transmission_method: po.transmission_method,
            sent_at: po.sent_at,
            line_ids: lines.map(&:id)
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

    def validate_lines!(lines)
      lines.each do |line|
        order = line.order
        raise Purchasing::Error, "line has a cancelled order" if order.cancelled?
        raise Purchasing::Error, "expected unit cost is required on every line" if line.expected_unit_cost_cents_snapshot.nil?
        raise Purchasing::Error, "expected unit cost must be nonnegative" if line.expected_unit_cost_cents_snapshot.negative?
        raise Purchasing::Error, "ordered quantity must be positive" unless line.ordered_quantity.positive?
        DraftPoPlacement.assert_standard_orderable!(line.product_variant)
      end
    end
  end
end
