# frozen_string_literal: true

require "test_helper"

class InventoryPostReturnTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "return_tax")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor)
    Pos::TenderTypes.seed!
  end

  test "posts paired return effects from the original sale depletion" do
    original = complete_sale
    original_line = original.pos_transaction_lines.first
    original_value = -InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: original_line.id,
      entry_type: "depletion"
    ).value_delta_cents
    return_line = add_return_line(original_line)
    occurred_at = Time.utc(2026, 8, 18, 18, 4, 22)
    business_date = Date.new(2026, 8, 18)
    result = nil
    PosTransaction.transaction do
      result = Inventory::PostReturn.call(
        line: return_line,
        occurred_at: occurred_at,
        business_date: business_date,
        actor: @actor
      )
    end

    ledger = result.fetch(:ledger)
    valuation = result.fetch(:valuation)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)

    assert_equal 1, ledger.quantity_delta
    assert_equal "return", ledger.entry_type
    assert_equal return_line.id, ledger.source_id
    assert_equal 200, original_value
    assert_equal 100, valuation.value_delta_cents
    assert_equal "acquisition", valuation.entry_type
    assert_nil valuation.reversal_of_id
    assert_equal 4, balance.on_hand_quantity
    assert_equal 400, balance.inventory_value_cents
    assert_equal 1, OutboxMessage.where(event_type: "inventory.return_posted").count
    assert AuditEvent.exists?(action: "inventory.return_posted", subject_id: return_line.id)
    assert_empty Inventory::LedgerPairIntegrity.drifts(store_id: @store.id, product_variant_id: @variant.id)
  end

  test "unlinked quantity restore uses the locked current moving average not the refund price" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 2,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: 1999
    )
    balance_before = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    result = nil
    PosTransaction.transaction do
      result = Inventory::PostReturn.call(
        line: line,
        occurred_at: Time.utc(2026, 8, 19, 17, 0, 0),
        business_date: Date.new(2026, 8, 19),
        actor: @actor
      )
    end

    valuation = result.fetch(:valuation)
    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 2, result.fetch(:ledger).quantity_delta
    assert_equal 200, valuation.value_delta_cents
    assert_equal "current_moving_average", valuation.calculation_metadata["valuation_basis"]
    assert_equal balance_before.on_hand_quantity + 2, balance.on_hand_quantity
    assert_equal balance_before.inventory_value_cents + 200, balance.inventory_value_cents
    assert_not_equal line.extended_selling_amount_cents, valuation.value_delta_cents
    event = AuditEvent.find_by!(action: "inventory.return_posted", subject_id: line.id)
    assert_equal "current_moving_average", event.after_values["valuation_basis"]
    outbox = OutboxMessage.find_by!(event_type: "inventory.return_posted", aggregate_id: line.id)
    assert_equal false, outbox.payload["linked"]
    assert_equal "current_moving_average", outbox.payload["valuation_basis"]
  end

  test "unlinked used restore posts the unit carrying value" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, unit_cost_cents: 500)
    sale = complete_unit_sale(unit)
    assert unit.reload.removed?
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    line = Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: 1200
    )
    result = nil
    PosTransaction.transaction do
      result = Inventory::PostReturn.call(
        line: line,
        occurred_at: Time.utc(2026, 8, 19, 17, 5, 0),
        business_date: Date.new(2026, 8, 19),
        actor: @actor
      )
    end

    assert_equal 500, result.fetch(:valuation).value_delta_cents
    assert_equal "unit_carrying_value", result.fetch(:valuation).calculation_metadata["valuation_basis"]
    outbox = OutboxMessage.where(event_type: "inventory.return_posted", aggregate_id: line.id).order(:created_at).last
    assert_equal false, outbox.payload["linked"]
    assert_equal "unit_carrying_value", outbox.payload["valuation_basis"]
    assert unit.reload.on_hand?
    assert_equal 500, unit.carrying_value_cents
    assert_equal used_variant.id, line.product_variant_id
    assert_nil line.original_transaction_line_id
    assert_not_equal sale.pos_transaction_lines.first.id, line.id
  end

  private

  def complete_sale
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 2
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    ).transaction
  end

  def add_return_line(original_line)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original_line,
      quantity: 1,
      reason_code: "defective"
    )
  end

  def complete_unit_sale(unit)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    ).transaction
  end
end
