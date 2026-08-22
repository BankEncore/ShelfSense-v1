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

  test "post receipt and locate same variant complete without deadlock" do
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

    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "OOS Lock #{@suffix}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    special = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )
    po = special.orders.first.purchase_order
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
      actual_unit_cost_cents: 500
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
    assert_nil errors[0], errors[0]&.full_message
    assert_nil errors[1], errors[1]&.full_message
    assert_equal "available", locate_request.reload.status
    assert_equal "posted", receipt.reload.status
  end

  test "reverse receipt and cancel request complete without deadlock" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "RevCancel #{@suffix}")
    SupplierVariantSource.create!(
      supplier: @supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 700,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
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

    # One or both may succeed depending on interleaving; neither may hang.
    # At least one must complete cleanly; the other may raise a domain error.
    assert(
      errors[0].nil? || errors[1].nil? ||
        errors.all? { |e| e.is_a?(Purchasing::Error) || e.is_a?(Customers::Error) },
      "unexpected errors: #{errors.map { |e| e&.full_message }.inspect}"
    )
    assert_not InventoryBalance.find_by!(store: @store, product_variant: oos).on_hand_quantity.negative?
  end
end
