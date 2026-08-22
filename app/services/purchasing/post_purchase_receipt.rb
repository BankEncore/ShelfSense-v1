# frozen_string_literal: true

module Purchasing
  class PostPurchaseReceipt
    def self.call(**attrs)
      new(**attrs).call
    end

    def initialize(
      purchase_receipt:,
      actor:,
      idempotency_key:,
      allow_backdate: false,
      expected_lock_version: nil,
      correlation_id: nil
    )
      @receipt = purchase_receipt
      @actor = actor
      @idempotency_key = idempotency_key
      @allow_backdate = allow_backdate
      @expected_lock_version = expected_lock_version
      @correlation_id = correlation_id || SecureRandom.uuid_v7
    end

    def call
      raise Purchasing::Error, "actor is required" if @actor.blank?
      raise Purchasing::Error, "idempotency key is required" if @idempotency_key.blank?

      payload = { purchase_receipt_id: @receipt.id, allow_backdate: @allow_backdate }
      op = Idempotency::OperationService.begin!(
        source_id: @receipt.id,
        operation_type: "post_purchase_receipt",
        idempotency_key: @idempotency_key,
        payload: payload
      )
      if op.replayed
        return PurchaseReceipt.find(op.operation.result_id) if op.operation.result_id

        raise Purchasing::Error, "idempotent replay missing result"
      end

      PurchaseReceipt.transaction do
        # Lock order: receipt → POs → PO lines → orders → balances (via PostReceipt)
        # → request / allocation (special-order allocate after balance)
        receipt = PurchaseReceipt.lock.find(@receipt.id)
        assert_lock_version!(receipt)
        raise Purchasing::Error, "only draft receipts can be posted" unless receipt.draft?

        lines = receipt.purchase_receipt_lines
          .includes(purchase_order_line: { purchase_order: [], order: :customer_request })
          .order(:id)
          .to_a
        raise Purchasing::Error, "receipt has no lines" if lines.empty?

        validate_received_at!(receipt)

        purchase_orders = lines.map { |line| line.purchase_order_line.purchase_order }.uniq.sort_by(&:id)
        purchase_orders.each { |po| PurchaseOrder.lock.find(po.id) }

        po_lines = lines.map(&:purchase_order_line).sort_by(&:id)
        po_lines.each { |po_line| PurchaseOrderLine.lock.find(po_line.id) }

        orders = po_lines.map(&:order).uniq.sort_by(&:id)
        orders.each { |order| Order.lock.find(order.id) }

        business_date = BusinessDate.for_store(receipt.store, at: receipt.received_at)
        posted_at = Time.current

        lines.each do |line|
          po_line = PurchaseOrderLine.lock.find(line.purchase_order_line_id)
          open_qty = po_line.open_quantity
          matched = [ line.received_quantity, [ open_qty, 0 ].max ].min
          unplanned = line.received_quantity - matched
          line.update!(matched_quantity: matched, unplanned_quantity: unplanned)

          Inventory::PostReceipt.call(
            purchase_receipt_line: line,
            occurred_at: receipt.received_at,
            business_date: business_date,
            actor: @actor,
            correlation_id: @correlation_id
          )

          allocate_special_order!(line) if matched.positive?
        end

        number = StoreDocumentSequence.next_number!(
          store: receipt.store,
          document_kind: "purchase_receipt"
        )

        receipt.update!(
          status: "posted",
          number: number,
          posted_at: posted_at,
          posted_by: @actor
        )

        purchase_orders.each do |po|
          ClosePurchaseOrderIfComplete.call!(
            purchase_order: po.reload,
            actor: @actor,
            correlation_id: @correlation_id
          )
        end

        Audit::Recorder.record!(
          action: "purchase_receipts.post",
          outcome: "succeeded",
          actor_user: @actor,
          store: receipt.store,
          subject: receipt,
          correlation_id: @correlation_id,
          after_values: {
            number: receipt.number,
            status: receipt.status,
            posted_at: receipt.posted_at,
            merchandise_total_cents: receipt.merchandise_total_cents,
            ancillary_total_cents: receipt.ancillary_total_cents,
            line_count: lines.size
          }
        )

        Outbox::Recorder.record!(
          event_type: "purchasing.receipt_posted",
          aggregate: receipt,
          correlation_id: @correlation_id,
          occurred_at: posted_at,
          payload: {
            purchase_receipt_id: receipt.id,
            store_id: receipt.store_id,
            supplier_id: receipt.supplier_id,
            number: receipt.number,
            posted_at: receipt.posted_at,
            line_ids: lines.map(&:id),
            merchandise_total_cents: receipt.merchandise_total_cents,
            ancillary_total_cents: receipt.ancillary_total_cents
          }
        )

        Idempotency::OperationService.complete!(
          op.operation,
          result_type: "PurchaseReceipt",
          result_id: receipt.id,
          result_payload: { id: receipt.id, number: receipt.number }
        )

        receipt
      end
    rescue Purchasing::Error, Inventory::PostReceipt::Error, ActiveRecord::RecordInvalid => e
      fail_operation!(op, e.message)
      raise Purchasing::Error, e.message
    rescue StandardError => e
      fail_operation!(op, e.message)
      raise
    end

    private

    def assert_lock_version!(receipt)
      return if @expected_lock_version.nil?
      return if receipt.lock_version == @expected_lock_version.to_i

      raise ActiveRecord::StaleObjectError.new(receipt, "update")
    end

    def validate_received_at!(receipt)
      raise Purchasing::Error, "received_at cannot be in the future" if receipt.received_at > Time.current + 1.second
      return if @allow_backdate

      store_today = BusinessDate.for_store(receipt.store)
      received_date = BusinessDate.for_store(receipt.store, at: receipt.received_at)
      return if received_date >= store_today

      raise Purchasing::Error, "backdating received_at requires purchase_receipts.backdate"
    end

    def allocate_special_order!(line)
      order = line.purchase_order_line.order
      request = order.customer_request
      return if request.blank?
      return if request.cancelled?
      return if request.completed?
      return unless %w[ordered special_order_pending].include?(request.status)
      return if line.matched_quantity < 1

      request.lock!
      return if request.active_allocation.present?

      CustomerRequestAllocation.create!(
        customer_request: request,
        allocation_type: "standard_quantity",
        purchase_receipt_line: line,
        quantity: 1,
        status: "reserved"
      )
      request.update!(status: "available")
    end

    def fail_operation!(op, message)
      return unless defined?(op) && op && !op.replayed

      Idempotency::OperationService.fail!(op.operation, message: message)
    end
  end
end
