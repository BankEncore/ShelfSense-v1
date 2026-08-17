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
    args = complete_args(operation_id: operation_id)
    first = Pos::CompleteTransaction.call(**args)
    second = Pos::CompleteTransaction.call(**args)

    assert second.replayed
    assert_equal first.transaction.id, second.transaction.id
    assert_equal first.operation.envelope_hash, second.operation.envelope_hash
    assert_equal 1, PosTransaction.where(register: @context[:register], receipt_sequence: 1).count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted").count
  end

  test "validation failure writes rejection audit and consumes no receipt" do
    operation_id = SecureRandom.uuid_v7
    error = assert_raises(Pos::Error) do
      Pos::CompleteTransaction.call(**complete_args(operation_id: operation_id, expected_total_cents: 1))
    end
    assert_match(/expected total/, error.message)
    assert @transaction.reload.working?
    assert_nil @transaction.receipt_sequence
    assert_equal 0, @context[:register].reload.receipt_sequence
    assert_equal "failed", PosOperation.find(operation_id).status
    assert_equal 0, OutboxMessage.where(event_type: "pos.transaction_completed").count
    assert_equal 0, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert AuditEvent.exists?(action: "pos.transaction_completion_rejected", outcome: "failed", subject_id: @transaction.id)
  end

  test "commit failure leaves the working transaction incomplete and marks the operation failed" do
    Pos::ChangeQuantity.call(
      transaction: @transaction,
      line: @transaction.pos_transaction_lines.first,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      quantity: 10
    )
    @transaction.reload
    Pos::TenderCash.call(
      transaction: @transaction,
      actor: @actor,
      expected_lock_version: @transaction.lock_version,
      amount_presented_cents: @transaction.total_cents
    )
    @transaction.reload
    operation_id = SecureRandom.uuid_v7

    error = assert_raises(Pos::Error) do
      Pos::CompleteTransaction.call(
        **complete_args(operation_id: operation_id, amount_presented_cents: @transaction.total_cents)
      )
    end
    assert_match(/insufficient|below zero/i, error.message)
    assert @transaction.reload.working?
    assert_nil @transaction.receipt_sequence
    assert_equal 0, @context[:register].reload.receipt_sequence
    assert_equal "failed", PosOperation.find(operation_id).status
    assert_equal 0, OutboxMessage.where(event_type: "pos.transaction_completed").count
    assert_equal 0, OutboxMessage.where(event_type: "inventory.sale_posted").count
    assert AuditEvent.exists?(action: "pos.transaction_completion_rejected", subject_id: @transaction.id)
  end

  test "same operation_id with a different command hash is an integrity failure" do
    operation_id = SecureRandom.uuid_v7
    Pos::CompleteTransaction.call(**complete_args(operation_id: operation_id))
    assert_raises(Pos::PayloadMismatch) do
      Pos::CompleteTransaction.call(**complete_args(operation_id: operation_id, amount_presented_cents: 9999))
    end
    assert_equal "completed", PosOperation.find(operation_id).status
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
  end

  test "unauthorized completion is denied without a receipt" do
    clerk = User.create!(
      username: "no_complete",
      display_name: "No Complete",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    assert_raises(Pos::Denied) do
      Pos::CompleteTransaction.call(**complete_args(actor: clerk))
    end
    assert @transaction.reload.working?
    assert_nil @transaction.receipt_sequence
    assert AuditEvent.exists?(action: "pos.transaction_completion_rejected", outcome: "denied", subject_id: @transaction.id)
  end

  test "unresolved store tax applicability blocks completion" do
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Unspecified local",
      rate_percent: "1.000",
      calculation_order: 2
    )
    error = assert_raises(Pos::Error) do
      Pos::CompleteTransaction.call(**complete_args)
    end
    assert_match(/applicability|applies/i, error.message)
    assert @transaction.reload.working?
    assert_nil @transaction.receipt_sequence
  end

  test "headless vertical slice matches Phase 4 acceptance" do
    envelope = Pos::CompleteTransaction.call(**complete_args).operation.envelope
    assert_equal 1, envelope.fetch("schema_version")
    assert_equal PosOperation::FACT_TYPE, envelope.fetch("operation").fetch("fact_type")
    assert envelope.fetch("receipt").fetch("sequence").present?
    assert_match(/\AS\d+-R\d+-T\d+\z/, envelope.fetch("receipt").fetch("reference"))
    line = envelope.fetch("lines").first
    assert_equal 1, line.fetch("quantity")
    assert_equal 1999, line.fetch("selling_unit_price_cents")
    assert line.fetch("tax_components").any? { |component| component.fetch("applies") }
    assert_equal "cash", envelope.fetch("tenders").first.fetch("tender_type")
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PosTransactionLine").count
    assert_equal 1, InventoryValuationEntry.where(source_type: "PosTransactionLine").count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
  end

  private

  def complete_args(operation_id: SecureRandom.uuid_v7, actor: @actor, expected_total_cents: @transaction.total_cents, amount_presented_cents: 2500)
    {
      transaction: @transaction,
      actor: actor,
      operation_id: operation_id,
      expected_lock_version: @transaction.lock_version,
      expected_total_cents: expected_total_cents,
      amount_presented_cents: amount_presented_cents
    }
  end
end
