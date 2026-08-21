# frozen_string_literal: true

require "test_helper"

class PosResolveAndOpenPriceTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @standard = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Example Book")
    open_quantity_stock(store: @store, variant: @standard, actor: @actor, quantity: 5)
    @open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price", name: "Open Book")
    open_quantity_stock(store: @store, variant: @open_price, actor: @actor, quantity: 5)
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "unique sellable scan resolves as addable without mutating" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @standard.sku
    )
    Pos::AddTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "card"),
      amount_cents: 100,
      external_reference: "AUTH-1"
    )
    transaction.reload
    lock = transaction.lock_version
    tender_count = transaction.pos_tenders.count

    result = Pos::ResolveMerchandiseForSale.call(
      store: @store,
      identifier: @open_price.sku,
      current_transaction: transaction
    )

    assert_equal :open_price_required, result.outcome
    assert_equal @open_price.id, result.variant.id
    transaction.reload
    assert_equal lock, transaction.lock_version
    assert_equal tender_count, transaction.pos_tenders.count
    assert_equal 1, transaction.pos_transaction_lines.count
  end

  test "initial open-price zero is allowed and negative is rejected before mutation" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    positive = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 500
    )
    assert_equal 500, positive.selling_unit_price_cents

    transaction.reload
    zero = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 0
    )
    assert_equal 0, zero.selling_unit_price_cents
    assert_equal 0, zero.reference_unit_price_cents
    assert_equal "open_price", zero.pricing_method_snapshot

    transaction.reload
    lock = transaction.lock_version
    line_count = transaction.pos_transaction_lines.count
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: lock,
        identifier: @open_price.sku,
        selling_price_cents: -1000
      )
    end
    assert_equal "open price cannot be negative", error.message
    transaction.reload
    assert_equal lock, transaction.lock_version
    assert_equal line_count, transaction.pos_transaction_lines.count
    assert_equal 0, transaction.pos_tenders.count
  end

  test "open-price used is refused with the locked message" do
    used = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      pricing_method: "open_price",
      variant_type: "used",
      name: "Open Used"
    )
    result = Pos::ResolveMerchandiseForSale.call(store: @store, identifier: used.sku)
    assert_equal :unavailable, result.outcome
    assert_equal Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE, result.message

    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddMerchandise.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: used.sku,
        selling_price_cents: 500
      )
    end
    assert_equal Pos::ResolveMerchandiseForSale::OPEN_PRICE_USED_MESSAGE, error.message
  end

  test "adds open-price standard with selling equal to reference and no price_override" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 500
    )

    assert_equal "open_price", line.pricing_method_snapshot
    assert_equal 500, line.reference_unit_price_cents
    assert_equal 500, line.selling_unit_price_cents
    assert_equal 0, line.pos_controlled_actions.count
    assert_equal 25, line.line_tax_cents
  end

  test "does not merge open-price lines on rescan" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 500
    )
    Pos::AddMerchandise.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 500
    )

    assert_equal 2, transaction.reload.pos_transaction_lines.count
  end

  test "open-price F6 edits both prices without a price_override and snapshot survives class change" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 500
    )
    Pos::AddTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "card"),
      amount_cents: 100,
      external_reference: "AUTH-2"
    )
    @open_price.merchandise_class.update_column(:default_pricing_method, "fixed")

    updated = Pos::UpdateOpenPrice.call(
      transaction: transaction.reload,
      line: line,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      selling_price_cents: 800
    )

    assert_equal "open_price", updated.pricing_method_snapshot
    assert_equal 800, updated.reference_unit_price_cents
    assert_equal 800, updated.selling_unit_price_cents
    assert_equal 0, updated.pos_controlled_actions.where(action_type: "price_override").count
    assert_equal 0, transaction.reload.pos_tenders.count
    assert_equal 40, updated.line_tax_cents

    error = assert_raises(Pos::Error) do
      Pos::ExecuteControlledAction.call(
        transaction: transaction.reload,
        line: updated,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        action_type: "price_override",
        operation: "apply",
        reason_code: "damaged",
        selling_unit_price_cents: 900
      )
    end
    assert_match(/open-price lines cannot use a price override/, error.message)
  end

  test "open-price F6 is refused when a discount exists" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @open_price.sku,
      selling_price_cents: 1000
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: line,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )

    error = assert_raises(Pos::Error) do
      Pos::UpdateOpenPrice.call(
        transaction: transaction.reload,
        line: line.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        selling_price_cents: 800
      )
    end
    assert_equal "Remove the line discount before changing the price.", error.message
    assert_equal 1000, line.reload.selling_unit_price_cents
    assert_equal 1000, line.manual_discount_basis_points
  end

  test "unit picker omits units on another working ticket and orders by identifier" do
    used, first_unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Picker")
    Inventory::AdjustmentReasons.seed!
    second = Inventory::PostAdjustment.call(
      store: @store,
      product_variant: used,
      adjustment_reason: AdjustmentReason.find_by!(code: "opening_inventory"),
      quantity_delta: 1,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      acquisition_unit_cost_cents: 500,
      regular_price_cents: 1200
    ).inventory_unit

    first = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: first,
      actor: @actor,
      expected_lock_version: first.lock_version,
      identifier: first_unit.unit_identifier
    )

    other = pos_open_context(store: @store, actor: @actor)
    second_tx = Pos::StartTransaction.call(session: other[:session], actor: @actor)
    result = Pos::ResolveMerchandiseForSale.call(
      store: @store,
      identifier: used.sku,
      current_transaction: second_tx
    )

    assert_equal :unit_choice_required, result.outcome
    assert_equal [ second.id ], result.units.map(&:id)
    assert_equal result.units.map(&:unit_identifier), result.units.map(&:unit_identifier).sort
  end
end
