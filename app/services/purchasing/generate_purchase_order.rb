# frozen_string_literal: true

module Purchasing
  class GeneratePurchaseOrder
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
        raise Purchasing::Error, "only draft purchase orders can be generated" unless po.draft?
        raise Purchasing::Error, "sent purchase orders cannot be generated" if po.sent_at.present?
        raise Purchasing::Error, "purchase order is already generated; return to draft first" if po.generated_at.present?
        raise Purchasing::Error, "supplier is inactive" unless po.supplier.active?

        lines = po.purchase_order_lines.includes(:order, :product_variant).to_a
        raise Purchasing::Error, "purchase order has no lines" if lines.empty?

        validate_lines!(lines)

        before = { number: po.number, document_revision: po.document_revision, generated_at: po.generated_at }
        regenerating = po.number.present?

        if po.number.blank?
          po.number = StoreDocumentSequence.next_number!(store: po.store, document_kind: "purchase_order")
        else
          po.document_revision = po.document_revision + 1
        end

        po.generated_at = Time.current
        po.generated_by = @actor
        po.save!

        Audit::Recorder.record!(
          action: regenerating ? "purchase_orders.regenerate" : "purchase_orders.generate",
          outcome: "succeeded",
          actor_user: @actor,
          store: po.store,
          subject: po,
          correlation_id: @correlation_id,
          before_values: before,
          after_values: {
            number: po.number,
            document_revision: po.document_revision,
            generated_at: po.generated_at,
            line_count: lines.size
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
        raise Purchasing::Error, "line #{line.id} has a cancelled order" if order.cancelled?
        raise Purchasing::Error, "line #{line.id} missing expected unit cost" if line.expected_unit_cost_cents_snapshot.nil?
        raise Purchasing::Error, "line #{line.id} expected unit cost must be nonnegative" if line.expected_unit_cost_cents_snapshot.negative?
        raise Purchasing::Error, "line #{line.id} ordered quantity must be positive" unless line.ordered_quantity.positive?
        DraftPoPlacement.assert_standard_orderable!(line.product_variant)
      end
    end
  end
end
