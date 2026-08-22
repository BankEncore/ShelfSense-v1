# frozen_string_literal: true

require "test_helper"

class Customers::CancelRequestConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @actor = User.find_by(username: "admin")
    unless @actor
      bootstrap = bootstrap!
      @actor = bootstrap[:administrator]
    end
    @store = Store.find_by!(code: "main")
    Inventory::AdjustmentReasons.seed!
    Authorization::PermissionCatalog.seed!(granted_by: @actor)
    @suffix = SecureRandom.hex(4)
    @tax = tax_class(code: "cc_#{@suffix}")
    @supplier = Supplier.create!(name: "Cancel Conc #{@suffix}", code: "cc_#{@suffix}")
    @customer = Customer.create!(display_name: "Cancel Conc Cust #{@suffix}", email: "cc_#{@suffix}@example.com")
  end

  teardown do
    conn = ActiveRecord::Base.connection
    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.disable_referential_integrity do
      tables.each { |table| conn.execute("TRUNCATE TABLE #{conn.quote_table_name(table)} CASCADE") }
    end
  end

  test "cancel versus Standard locate does not leave reserved allocation on cancelled request" do
    variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Cancel Std #{@suffix}")
    open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 1, unit_cost_cents: 400)
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: variant,
      actor: @actor
    )

    errors = Array.new(2)
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::CancelRequest.call(
            customer_request: request,
            actor: @actor,
            reason: "concurrent cancel"
          )
        rescue StandardError => e
          errors[0] = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::ConfirmLocation.call(
            customer_request: request,
            actor: @actor
          )
        rescue StandardError => e
          errors[1] = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }
    assert_no_lock_failures!(errors)

    request.reload
    assert_no_orphan_allocation_on_cancel!(request)
    assert_not request.cancelled? && request.active_allocation&.reserved?,
               "cancelled request must not retain a reserved allocation"
  end

  test "cancel versus Used locate does not leave reserved allocation on cancelled request" do
    variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Cancel Used #{@suffix}")
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: variant,
      actor: @actor
    )

    errors = Array.new(2)
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::CancelRequest.call(
            customer_request: request,
            actor: @actor,
            reason: "concurrent cancel"
          )
        rescue StandardError => e
          errors[0] = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::ConfirmLocation.call(
            customer_request: request,
            actor: @actor,
            inventory_unit: unit
          )
        rescue StandardError => e
          errors[1] = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }
    assert_no_lock_failures!(errors)

    request.reload
    assert_no_orphan_allocation_on_cancel!(request)
  end

  test "cancel versus special-order receipt allocation does not leave reserved allocation on cancelled request" do
    variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Cancel Rcpt #{@suffix}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 700,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: variant,
      actor: @actor,
      supplier: @supplier,
      expected_unit_cost_cents: 700
    )
    po = request.orders.first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    po_line = po.purchase_order_lines.first
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: po_line,
      actor: @actor,
      received_quantity: 1,
      actual_unit_cost_cents: 700
    )

    errors = Array.new(2)
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::CancelRequest.call(
            customer_request: request,
            actor: @actor,
            reason: "concurrent cancel",
            cancel_draft_order: false
          )
        rescue StandardError => e
          errors[0] = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Purchasing::PostPurchaseReceipt.call(
            purchase_receipt: receipt,
            actor: @actor,
            idempotency_key: SecureRandom.uuid_v7
          )
        rescue StandardError => e
          errors[1] = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }
    assert_no_lock_failures!(errors)

    request.reload
    assert_no_orphan_allocation_on_cancel!(request)
  end

  test "cancel draft order rejects when purchase order was sent concurrently" do
    variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Cancel Send #{@suffix}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 600,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: variant,
      actor: @actor,
      supplier: @supplier
    )
    po = request.orders.first.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)

    errors = Array.new(2)
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Purchasing::SendPurchaseOrder.call(
            purchase_order: po,
            actor: @actor,
            transmission_method: "email"
          )
        rescue StandardError => e
          errors[0] = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::CancelRequest.call(
            customer_request: request,
            actor: @actor,
            reason: "concurrent cancel",
            cancel_draft_order: true
          )
        rescue StandardError => e
          errors[1] = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }
    assert_no_lock_failures!(errors)

    po.reload
    request.reload
    cancel_error = errors.compact.find { |e| e.is_a?(Customers::Error) && e.message == Customers::CancelRequest::SENT_PO_CONFLICT }
    if cancel_error
      assert_equal "sent", po.status
      assert_not request.cancelled?, "request should remain active when draft-order cancel loses to send"
      assert PurchaseOrderLine.find_by(order_id: request.orders.first.id).present?
    else
      assert request.cancelled?, "expected cancel to finish when no sent-PO conflict was raised"
      order = request.orders.first
      if po.sent?
        assert_nil order.reload.cancelled_at
        assert PurchaseOrderLine.find_by(order_id: order.id).present?
      else
        assert_not_equal "sent", po.status
      end
    end
  end

  private

  def assert_no_orphan_allocation_on_cancel!(request)
    return unless request.cancelled?

    reserved = request.customer_request_allocations.reserved
    assert_empty reserved, "cancelled request #{request.id} retained reserved allocations: #{reserved.map(&:id)}"
  end

  def assert_no_lock_failures!(errors)
    errors.compact.each do |error|
      message = "#{error.class}: #{error.message}"
      assert_not_kind_of ActiveRecord::Deadlocked, error, message
      assert_not_kind_of ActiveRecord::LockWaitTimeout, error, message
      assert_no_match(/deadlock detected|lock timeout|canceling statement due to statement timeout/i, message)
    end
  end
end
