# frozen_string_literal: true

require "test_helper"

class Pos::AllocationPickupTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    Inventory::AdjustmentReasons.seed!
    Pos::TenderTypes.seed!
    @tax = tax_class(code: "pickup_tax_#{SecureRandom.hex(2)}")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Pickup Tax",
      rate_percent: "0.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Pickup Book")
    @customer = Customer.create!(display_name: "Alex Pickup", phone: "555-0100")
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "ordinary sale still blocked when reserved" do
    request = locate_standard_request!

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
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
    assert_equal "available", request.reload.status
    assert request.active_allocation.reserved?
  end

  test "pickup line succeeds and fulfills request" do
    request = locate_standard_request!
    allocation = request.active_allocation

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddPickupMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer_request: request
    )
    assert_equal allocation.id, line.customer_request_allocation_id
    assert_equal 1, line.quantity
    assert_nil line.inventory_unit_id

    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )

    request.reload
    allocation.reload
    assert_equal "completed", request.status
    assert request.completed_at.present?
    assert_equal "fulfilled", allocation.status
    assert_equal line.id, allocation.fulfilled_pos_transaction_line_id
    assert_equal 0, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
    assert_equal 0, Inventory::Availability.active_reserved_quantity(@store, @variant)
  end

  test "cancelled working transaction leaves allocation available" do
    request = locate_standard_request!
    allocation = request.active_allocation

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddPickupMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer_request: request
    )
    transaction.reload
    Pos::CancelTransaction.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )

    assert_equal "cancelled", transaction.reload.status
    assert_equal "available", request.reload.status
    assert_equal "reserved", allocation.reload.status
    assert_nil allocation.fulfilled_pos_transaction_line_id
    assert_equal 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
  end

  test "wrong Used unit rejected at PostSale" do
    used_variant, allocated_unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Pickup A")
    _other_variant, other_unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Pickup B")
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: used_variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(
      customer_request: request,
      actor: @actor,
      inventory_unit: allocated_unit
    )
    allocation = request.reload.active_allocation

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = PosTransactionLine.new(
      pos_transaction: transaction,
      product_variant: used_variant,
      inventory_unit: other_unit,
      customer_request_allocation: allocation,
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

    error = assert_raises(Inventory::PostSale::Error) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: line,
          occurred_at: Time.current,
          business_date: Date.current,
          actor: @actor
        )
      end
    end
    assert_match(/allocation|unit/i, error.message)
    assert allocated_unit.reload.on_hand?
    assert_equal "reserved", allocation.reload.status
  end

  test "cannot consume another request's allocation" do
    used_a, unit_a = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Alloc A")
    used_b, unit_b = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Alloc B")
    request_a = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: used_a,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request_a, actor: @actor, inventory_unit: unit_a)
    other = Customer.create!(display_name: "Other Pickup", phone: "555-0199")
    request_b = Customers::CreateRequest.call(
      store: @store,
      customer: other,
      product_variant: used_b,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request_b, actor: @actor, inventory_unit: unit_b)
    allocation_a = request_a.reload.active_allocation

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    # Line claims request A's allocation but tries to sell request B's unit.
    line = PosTransactionLine.new(
      pos_transaction: transaction,
      product_variant: used_a,
      inventory_unit: unit_b,
      customer_request_allocation: allocation_a,
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

    error = assert_raises(Inventory::PostSale::Error) do
      PosTransaction.transaction do
        Inventory::PostSale.call(
          line: line,
          occurred_at: Time.current,
          business_date: Date.current,
          actor: @actor
        )
      end
    end
    assert_match(/allocation|unit|variant/i, error.message)
    assert_equal "reserved", allocation_a.reload.status
    assert_equal "reserved", request_b.reload.active_allocation.status
    assert unit_a.reload.on_hand?
    assert unit_b.reload.on_hand?
  end

  test "Used pickup uses exact allocated unit and fulfills" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Exact")
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: used_variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request, actor: @actor, inventory_unit: unit)
    allocation = request.reload.active_allocation

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddPickupMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer_request: request
    )
    assert_equal allocation.id, line.customer_request_allocation_id
    assert_equal unit.id, line.inventory_unit_id

    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )

    assert_equal "completed", request.reload.status
    assert_equal "fulfilled", allocation.reload.status
    assert_equal "removed", unit.reload.lifecycle_state
  end

  test "search finds available requests by name phone number and merchandise" do
    request = locate_standard_request!

    by_name = Pos::SearchAvailableCustomerRequests.call(store: @store, query: "Alex")
    assert_includes by_name.map { |row| row.customer_request.id }, request.id

    by_phone = Pos::SearchAvailableCustomerRequests.call(store: @store, query: "555-0100")
    assert_includes by_phone.map { |row| row.customer_request.id }, request.id

    by_number = Pos::SearchAvailableCustomerRequests.call(store: @store, query: request.number.to_s)
    assert_includes by_number.map { |row| row.customer_request.id }, request.id

    by_sku = Pos::SearchAvailableCustomerRequests.call(store: @store, query: @variant.sku)
    assert_includes by_sku.map { |row| row.customer_request.id }, request.id
  end

  private

  def locate_standard_request!
    request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
    Customers::ConfirmLocation.call(customer_request: request, actor: @actor)
    request.reload
  end
end
