# frozen_string_literal: true

require "test_helper"

class Customers::RequestAndAvailabilityTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    @tax = tax_class(code: "cr_tax_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Reserved Book")
    @customer = Customer.create!(display_name: "Pat Customer", email: "pat@example.com")
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1, unit_cost_cents: 100)
  end

  test "create in-stock request assigns store-scoped number and pending_location" do
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    assert_equal 1, request.number
    assert_equal "pending_location", request.status
    assert_nil request.active_allocation
    assert_equal 1, Inventory::Availability.available(@store, @variant)
  end

  test "locate Standard reserves and PostSale of last available fails" do
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request, actor: @actor)
    request.reload

    assert_equal "available", request.status
    allocation = request.active_allocation
    assert allocation.present?
    assert_equal "standard_quantity", allocation.allocation_type
    assert_equal "reserved", allocation.status
    assert_equal 0, Inventory::Availability.available(@store, @variant)
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity

    context = pos_open_context(store: @store, actor: @actor)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: @variant.sku,
        quantity: 1
      )
    end
    assert_match(/reserved|available/i, error.message)

    # Authoritative posting-time hard-stop even if a line were present
    line = PosTransactionLine.new(
      pos_transaction: transaction,
      product_variant: @variant,
      quantity: 1,
      direction: "sale",
      line_number: 1,
      reference_unit_price_cents: 1999,
      selling_unit_price_cents: 1999,
      extended_selling_amount_cents: 1999,
      net_merchandise_amount_cents: 1999,
      pricing_method_snapshot: "configured",
      tax_class: @tax,
      tax_class_code_snapshot: @tax.code,
      tax_class_name_snapshot: @tax.name
    )
    line.id = SecureRandom.uuid_v7
    line.save!(validate: false)

    post_error = assert_raises(Inventory::PostSale::Error) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: line,
          occurred_at: Time.current,
          business_date: Date.current,
          actor: @actor
        )
      end
    end
    assert_match(/available|reserved/i, post_error.message)
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
  end

  test "allocated Used unit cannot PostSale" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Reserve")
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: used_variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(
      customer_request: request,
      actor: @actor,
      inventory_unit: unit
    )

    assert Inventory::Availability.unit_allocated?(unit)
    context = pos_open_context(store: @store, actor: @actor)
    transaction = Pos::StartTransaction.call(session: context[:session], actor: @actor)
    add_error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: unit.unit_identifier
      )
    end
    assert_match(/reserved/i, add_error.message)

    line = PosTransactionLine.new(
      pos_transaction: transaction,
      product_variant: used_variant,
      inventory_unit: unit,
      quantity: 1,
      direction: "sale",
      line_number: 1,
      reference_unit_price_cents: 1200,
      selling_unit_price_cents: 1200,
      extended_selling_amount_cents: 1200,
      net_merchandise_amount_cents: 1200,
      pricing_method_snapshot: "configured",
      tax_class: @tax,
      tax_class_code_snapshot: @tax.code,
      tax_class_name_snapshot: @tax.name
    )
    line.id = SecureRandom.uuid_v7
    line.save!(validate: false)

    post_error = assert_raises(Inventory::PostSale::Error) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: line,
          occurred_at: Time.current,
          business_date: Date.current,
          actor: @actor
        )
      end
    end
    assert_match(/reserved/i, post_error.message)
    assert unit.reload.on_hand?
  end

  test "negative PostAdjustment blocked when it would break available" do
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request, actor: @actor)

    error = assert_raises(Inventory::PostAdjustment::Error) do
      Inventory::PostAdjustment.call(
        store: @store,
        product_variant: @variant,
        adjustment_reason: AdjustmentReason.find_by!(code: "shrinkage"),
        quantity_delta: -1,
        actor: @actor,
        source_id: SecureRandom.uuid_v7,
        idempotency_key: SecureRandom.uuid_v7,
        notes: "would steal reserve"
      )
    end
    assert_match(/available|reserved/i, error.message)
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
  end

  test "competing locate second fails when only one available" do
    second_customer = Customer.create!(display_name: "Other Customer")
    first = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    second = Customers::CreateRequest.call(
      store: @store,
      customer: second_customer,
      product_variant: @variant,
      actor: @actor
    )

    Customers::ConfirmLocation.call(customer_request: first, actor: @actor)
    error = assert_raises(Customers::Error) do
      Customers::ConfirmLocation.call(customer_request: second, actor: @actor)
    end
    assert_match(/no available/i, error.message)
    assert_equal "pending_location", second.reload.status
    assert_equal "available", first.reload.status
  end

  test "OOS Standard create routes to special order" do
    oos = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "OOS Book")
    supplier = Supplier.create!(name: "OOS Supplier", code: "oos_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier,
      product_variant: oos,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 600,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: oos,
      actor: @actor
    )
    assert_equal "special_order_pending", request.status
    assert_equal 1, request.orders.count
    assert request.orders.first.purchase_order_line.present?
  end

  test "unlocated Used cancels" do
    used_variant, = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Cancel")
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: used_variant,
      actor: @actor
    )
    Customers::ResolveNotLocated.call(
      customer_request: request,
      actor: @actor,
      notes: "could not find on shelf"
    )
    request.reload
    assert_equal "cancelled", request.status
    assert_equal "not located", request.cancellation_reason
    assert request.location_failed_at.present?
    assert_equal @actor, request.location_failed_by
  end

  test "OOS Used create is rejected" do
    used = pos_sellable_variant(actor: @actor, tax_class: @tax, variant_type: "used", name: "No Unit Used")
    error = assert_raises(Customers::Error) do
      Customers::CreateRequest.call(
        store: @store,
        customer: @customer,
        product_variant: used,
        actor: @actor
      )
    end
    assert_match(/out-of-stock Used/i, error.message)
  end

  test "convert to special order creates order and draft line" do
    supplier = Supplier.create!(name: "Convert Supp", code: "cv_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 550,
      organization_preferred: true
    )
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    Customers::ResolveNotLocated.call(
      customer_request: request,
      actor: @actor,
      convert_to_special_order: true,
      notes: "not on shelf"
    )
    request.reload
    assert_equal "special_order_pending", request.status
    assert_equal 1, request.orders.count
    assert_equal "draft", request.orders.first.purchase_order.status
  end
end
