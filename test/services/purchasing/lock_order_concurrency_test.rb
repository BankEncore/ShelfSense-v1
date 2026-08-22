# frozen_string_literal: true

require "test_helper"

class Purchasing::LockOrderConcurrencyTest < ActiveSupport::TestCase
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
    @tax = tax_class(code: "loc_#{@suffix}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Lock #{@suffix}")
    @supplier = Supplier.create!(name: "Lock Supp #{@suffix}", code: "lk_#{@suffix}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 400,
      organization_preferred: true
    )
    @customer = Customer.create!(display_name: "Lock Cust #{@suffix}", email: "lock_#{@suffix}@example.com")
  end

  teardown do
    conn = ActiveRecord::Base.connection
    tables = conn.tables - %w[schema_migrations ar_internal_metadata]
    conn.disable_referential_integrity do
      tables.each { |table| conn.execute("TRUNCATE TABLE #{conn.quote_table_name(table)} CASCADE") }
    end
  end

  test "post receipt and locate compete on the same InventoryBalance without deadlock" do
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "opening_inventory"),
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 400
    )
    locate_request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    assert_equal "pending_location", locate_request.status

    # Stock receipt for the same variant so PostReceipt and ConfirmLocation share one balance.
    order = Purchasing::CreateStockOrder.call(
      store: @store,
      product_variant: @variant,
      actor: @actor,
      quantity: 1,
      supplier: @supplier
    )
    po = order.purchase_order
    Purchasing::GeneratePurchaseOrder.call(purchase_order: po, actor: @actor)
    Purchasing::SendPurchaseOrder.call(
      purchase_order: po.reload,
      actor: @actor,
      transmission_method: "email"
    )
    receipt = Purchasing::CreateDraftPurchaseReceipt.call(
      store: @store,
      supplier: @supplier,
      actor: @actor
    )
    Purchasing::AddPurchaseReceiptLine.call(
      purchase_receipt: receipt,
      purchase_order_line: po.purchase_order_lines.first,
      actor: @actor,
      received_quantity: 1,
      actual_unit_cost_cents: 400
    )

    errors = Array.new(2)
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Purchasing::PostPurchaseReceipt.call(
            purchase_receipt: receipt,
            actor: @actor,
            idempotency_key: SecureRandom.uuid_v7
          )
        rescue StandardError => e
          errors[0] = e
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Customers::ConfirmLocation.call(
            customer_request: locate_request,
            actor: @actor
          )
        rescue StandardError => e
          errors[1] = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }
    assert_no_lock_failures!(errors)
    assert_nil errors[0], errors[0]&.full_message
    assert_nil errors[1], errors[1]&.full_message
    assert_equal "available", locate_request.reload.status
    assert_equal "posted", receipt.reload.status
  end

  test "reverse receipt and cancel request on same allocation complete without deadlock" do
    InventoryBalance.find_or_create_by!(store: @store, product_variant: @variant).update!(
      on_hand_quantity: 0,
      inventory_value_cents: 0
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor,
      supplier: @supplier,
      expected_unit_cost_cents: 700
    )
    assert request.orders.any?, "expected special-order path for OOS variant"

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
    Purchasing::PostPurchaseReceipt.call(
      purchase_receipt: receipt,
      actor: @actor,
      idempotency_key: SecureRandom.uuid_v7
    )
    line = receipt.purchase_receipt_lines.first
    assert request.reload.active_allocation.present?

    errors = Array.new(2)
    threads = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Purchasing::ReversePurchaseReceiptLine.call(
            purchase_receipt_line: line,
            actor: @actor,
            reason: "concurrent reverse",
            idempotency_key: SecureRandom.uuid_v7
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
            reason: "concurrent cancel"
          )
        rescue StandardError => e
          errors[1] = e
        end
      end
    ]
    threads.each { |thread| assert thread.join(30), "thread did not finish (possible deadlock)" }
    assert_no_lock_failures!(errors)

    assert(
      errors[0].nil? || errors[1].nil? ||
        errors.compact.all? { |e|
          e.is_a?(Purchasing::Error) || e.is_a?(Customers::Error) || e.is_a?(ActiveRecord::StaleObjectError)
        },
      "unexpected errors: #{errors.map { |e| e&.class&.name }.inspect} #{errors.map { |e| e&.full_message }.inspect}"
    )
    assert_not InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity.negative?
  end

  private

  def assert_no_lock_failures!(errors)
    errors.compact.each do |error|
      message = "#{error.class}: #{error.message}"
      assert_not_kind_of ActiveRecord::Deadlocked, error, message
      assert_not_kind_of ActiveRecord::LockWaitTimeout, error, message
      assert_no_match(/deadlock detected|lock timeout|canceling statement due to statement timeout/i, message)
    end
  end
end
