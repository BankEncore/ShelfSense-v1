# frozen_string_literal: true

require "test_helper"

class PosCompleteTransactionTest < ActiveSupport::TestCase
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
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor)
    @transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: @transaction,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      identifier: @variant.sku
    )
    @transaction.reload
    Pos::TenderCash.call(
      transaction: @transaction,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      amount_presented_cents: 2500
    )
    @transaction.reload
  end

  test "completes a cash sale into Core, envelope, inventory, audit, and outbox" do
    operation_id = SecureRandom.uuid_v7
    result = Pos::CompleteTransaction.call(
      transaction: @transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: @transaction.lock_version,
      expected_total_cents: @transaction.total_cents,
      amount_presented_cents: 2500
    )

    transaction = result.transaction
    operation = result.operation
    assert_not result.replayed
    assert transaction.completed?
    assert_equal 1, transaction.receipt_sequence
    assert_equal "1", transaction.store_number_snapshot
    assert_equal @context[:register].register_number, transaction.register_number_snapshot
    assert_equal "S001-R01-T0000001", transaction.transaction_reference
    assert_equal @context[:period].business_date, transaction.business_date
    assert_equal transaction.occurred_at, transaction.completed_at
    assert_equal 1, transaction.pos_transaction_lines.first.pos_line_tax_components.count
    assert_equal 100, transaction.pos_transaction_lines.first.line_tax_cents

    assert_equal "completed", operation.status
    assert_equal PosOperation::FACT_TYPE, operation.fact_type
    assert_equal operation_id, operation.id
    assert_equal operation_id, operation.idempotency_key
    assert_equal @context[:register].id, operation.source_id
    assert_equal Idempotency::CanonicalJson.hash(operation.envelope), operation.envelope_hash
    assert_equal transaction.receipt_sequence, operation.envelope.dig("receipt", "sequence")
    assert_equal transaction.transaction_reference, operation.envelope.dig("receipt", "reference")

    balance = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    assert_equal 4, balance.on_hand_quantity
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: transaction.pos_transaction_lines.first.id).count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert AuditEvent.exists?(action: "pos.transaction_completed", outcome: "succeeded", subject_id: transaction.id)
  end

  test "replay of the same operation_id does not allocate another receipt or outbox" do
    operation_id = SecureRandom.uuid_v7
    args = {
      transaction: @transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: @transaction.lock_version,
      expected_total_cents: @transaction.total_cents,
      amount_presented_cents: 2500
    }
    first = Pos::CompleteTransaction.call(**args)
    second = Pos::CompleteTransaction.call(**args)

    assert second.replayed
    assert_equal first.transaction.id, second.transaction.id
    assert_equal first.operation.envelope_hash, second.operation.envelope_hash
    assert_equal 1, PosTransaction.where(register: @context[:register], receipt_sequence: 1).count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted").count
  end
end
