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
    assert_equal 1, transaction.store_number_snapshot
    assert_equal 1, transaction.register_number_snapshot
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
    assert_equal 1, operation.envelope.dig("receipt", "store_number")
    assert_equal 1, operation.envelope.dig("receipt", "register_number")
    assert_equal transaction.transaction_reference, operation.envelope.dig("receipt", "reference")
    assert_equal @actor.id.to_s, operation.envelope.dig("origin", "performed_by_user_id")
    assert_equal @actor.id, transaction.cashier_user_id
    assert_equal @actor.id, transaction.pos_session.cashier_user_id

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
    assert AuditEvent.exists?(
      action: "pos.transaction_completion_rejected",
      outcome: "failed",
      subject_id: @transaction.id
    )
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

  test "second cashier cannot complete another cashier's transaction" do
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_cashier")
    assert_raises(Pos::Denied) do
      Pos::CompleteTransaction.call(**complete_args(actor: other))
    end
    assert @transaction.reload.working?
    assert_nil @transaction.receipt_sequence
    assert AuditEvent.exists?(action: "pos.transaction_completion_rejected", outcome: "denied", subject_id: @transaction.id)
  end

  test "same operation_id reused against another register is rejected" do
    operation_id = SecureRandom.uuid_v7
    Pos::CompleteTransaction.call(**complete_args(operation_id: operation_id))

    other_context = pos_open_context(store: @store, actor: @actor)
    other_transaction = Pos::StartTransaction.call(session: other_context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: other_transaction,
      actor: @actor,
      expected_lock_version: other_transaction.lock_version,
      identifier: @variant.sku
    )
    other_transaction.reload
    Pos::TenderCash.call(
      transaction: other_transaction,
      actor: @actor,
      expected_lock_version: other_transaction.lock_version,
      amount_presented_cents: 2500
    )
    other_transaction.reload

    error = assert_raises(Pos::OperationLease::Error) do
      Pos::CompleteTransaction.call(
        transaction: other_transaction,
        actor: @actor,
        operation_id: operation_id,
        expected_lock_version: other_transaction.lock_version,
        expected_total_cents: other_transaction.total_cents,
        amount_presented_cents: 2500
      )
    end
    assert_match(/another register/, error.message)
    assert other_transaction.reload.working?
    assert AuditEvent.exists?(
      action: "pos.transaction_completion_rejected",
      outcome: "failed",
      subject_id: other_transaction.id
    )
  end

  test "replay of a completed operation succeeds after the register is deactivated" do
    operation_id = SecureRandom.uuid_v7
    first = Pos::CompleteTransaction.call(**complete_args(operation_id: operation_id))
    Pos::CloseSession.call(
      session: @context[:session].reload,
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 0
    )
    Pos::FinalizeReportingPeriod.call(
      period: @context[:period].reload,
      actor: @actor,
      expected_lock_version: @context[:period].lock_version
    )
    @context[:register].reload.update!(active: false, deactivated_at: Time.current, deactivated_by: @actor)

    second = Pos::CompleteTransaction.call(**complete_args(operation_id: operation_id))
    assert second.replayed
    assert_equal first.operation.envelope_hash, second.operation.envelope_hash
  end

  test "completed facts are readonly" do
    result = Pos::CompleteTransaction.call(**complete_args)
    transaction = result.transaction
    line = transaction.pos_transaction_lines.first
    tender = transaction.pos_tenders.first
    component = line.pos_line_tax_components.first

    assert_raises(ActiveRecord::ReadOnlyRecord) { transaction.update!(subtotal_cents: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { line.update!(quantity: 2) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { tender.update!(change_cents: 0) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { component.update!(tax_cents: 0) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { result.operation.update!(producer_client: "tampered") }
  end

  test "headless vertical slice matches Phase 4 acceptance" do
    envelope = Pos::CompleteTransaction.call(**complete_args).operation.envelope
    assert_equal 2, envelope.fetch("schema_version")
    assert_equal envelope.fetch("transaction").fetch("total_cents"), envelope.fetch("transaction").fetch("signed_net_cents")
    refute envelope.fetch("lines").first.key?("inventory_unit_id")
    assert_equal PosOperation::FACT_TYPE, envelope.fetch("operation").fetch("fact_type")
    assert envelope.fetch("receipt").fetch("sequence").present?
    assert_kind_of Integer, envelope.fetch("receipt").fetch("store_number")
    assert_kind_of Integer, envelope.fetch("receipt").fetch("register_number")
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
