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
end
