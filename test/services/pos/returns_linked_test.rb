# frozen_string_literal: true

require "test_helper"

class PosReturnsLinkedTest < ActiveSupport::TestCase
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 50_000)
    Pos::TenderTypes.seed!
    @cash = TenderType.find_by!(code: "cash")
  end

  test "linked quantity return restores original depletion and envelope return keys" do
    original = complete_quantity_sale!(quantity: 1)
    original_line = original.pos_transaction_lines.first
    original_valuation = InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: original_line.id,
      entry_type: "depletion"
    )
    balance_after_sale = InventoryBalance.find_by!(store: @store, product_variant: @variant)
    on_hand_after_sale = balance_after_sale.on_hand_quantity

    result = complete_linked_return!(original_line: original_line, quantity: 1)
    return_txn = result.transaction
    return_line = return_txn.pos_transaction_lines.first
    envelope = result.operation.envelope

    assert return_txn.completed?
    assert_equal 0, return_txn.subtotal_cents
    assert_equal original_line.extended_selling_amount_cents, return_txn.return_subtotal_cents
    assert_equal original_line.line_tax_cents, return_txn.return_tax_cents
    assert_equal original_line.line_total_cents, return_txn.return_total_cents
    assert_equal(-original_line.line_total_cents, return_txn.signed_net_cents)
    assert_equal original_line.line_total_cents, return_txn.total_cents
    assert_equal "return", envelope.dig("lines", 0, "direction")
    assert_equal original_line.id.to_s, envelope.dig("lines", 0, "original_transaction_line_id")
    assert_equal "changed_mind", envelope.dig("lines", 0, "return_reason", "code")
    refute envelope.fetch("transaction").key?("sale_total_cents")
    refute envelope.key?("corrections")
    refund = envelope.fetch("tenders").first
    assert_equal "refund", refund.fetch("direction")
    refute refund.key?("amount_presented_cents")
    refute refund.key?("change_cents")
    Pos::CompletedTransactionFacts.new(envelope).verify!

    ledger = InventoryLedgerEntry.find_by!(source_type: "PosTransactionLine", source_id: return_line.id)
    valuation = InventoryValuationEntry.find_by!(source_type: "PosTransactionLine", source_id: return_line.id)
    assert_equal "return", ledger.entry_type
    assert_equal 1, ledger.quantity_delta
    assert_equal "acquisition", valuation.entry_type
    assert_nil valuation.reversal_of_id
    assert_equal(-original_valuation.value_delta_cents, valuation.value_delta_cents)
    assert_equal on_hand_after_sale + 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
    assert_equal 1, OutboxMessage.where(event_type: "inventory.return_posted").count
    assert AuditEvent.exists?(action: "inventory.return_posted", subject_id: return_line.id)
    assert AuditEvent.exists?(action: "pos.linked_return.added", subject_id: return_line.id)
  end

  test "linked Used return restores the original unit and sale carrying value" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, unit_cost_cents: 500)
    original = complete_unit_sale!(unit)
    original_line = original.pos_transaction_lines.first
    original_value = -InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: original_line.id,
      entry_type: "depletion"
    ).value_delta_cents
    assert unit.reload.removed?

    result = complete_linked_return!(original_line: original_line, quantity: 1)
    return_line = result.transaction.pos_transaction_lines.first
    unit.reload
    assert unit.on_hand?
    assert_nil unit.removed_at
    assert_equal original_value, unit.carrying_value_cents
    valuation = InventoryValuationEntry.find_by!(source_type: "PosTransactionLine", source_id: return_line.id)
    assert_equal original_value, valuation.value_delta_cents
    assert_equal unit.id, valuation.inventory_unit_id
    assert_equal used_variant.id, return_line.product_variant_id
  end

  test "two partials then remainder reverse original discount tax and cost exactly" do
    original = complete_quantity_sale!(quantity: 3, discount_basis_points: 1000)
    original_line = original.pos_transaction_lines.first
    original_discount = original_line.manual_discount_cents
    original_tax = original_line.line_tax_cents
    original_cost = -InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: original_line.id,
      entry_type: "depletion"
    ).value_delta_cents

    first = complete_linked_return!(original_line: original_line, quantity: 1)
    second = complete_linked_return!(original_line: original_line, quantity: 1)
    remainder = complete_linked_return!(original_line: original_line, quantity: 1)
    returned = [ first, second, remainder ].map { |result| result.transaction.pos_transaction_lines.first }

    assert_equal original_discount, returned.sum(&:manual_discount_cents)
    assert_equal original_tax, returned.sum(&:line_tax_cents)
    restored = InventoryValuationEntry.where(
      source_type: "PosTransactionLine",
      source_id: returned.map(&:id),
      entry_type: "acquisition"
    ).sum(:value_delta_cents)
    assert_equal original_cost, restored
    original_line.pos_line_tax_components.each do |component|
      reversed = PosLineTaxComponent.where(pos_transaction_line_id: returned.map(&:id), store_tax_id: component.store_tax_id)
                                    .sum(:tax_cents)
      assert_equal component.tax_cents, reversed
    end
  end

  test "working and cancelled returns do not consume eligibility or residual cents" do
    original = complete_quantity_sale!(quantity: 1)
    original_line = original.pos_transaction_lines.first
    working = start_return_transaction
    working_line = Pos::AddLinkedReturnLine.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      original_line: original_line,
      quantity: 1,
      reason_code: "defective"
    )
    assert_equal 1, Pos::Returnability.remaining_quantity(original_line)

    Pos::CancelTransaction.call(
      transaction: working.reload,
      actor: @actor,
      expected_lock_version: working.lock_version
    )
    assert working.reload.cancelled?
    assert_equal 1, Pos::Returnability.remaining_quantity(original_line)

    completed = complete_linked_return!(original_line: original_line, quantity: 1)
    assert completed.transaction.completed?
    assert_equal 0, Pos::Returnability.remaining_quantity(original_line)
    assert_not_equal working_line.id, completed.transaction.pos_transaction_lines.first.id
  end

  test "a second register cannot complete after the last remaining quantity is returned" do
    original = complete_quantity_sale!(quantity: 1)
    original_line = original.pos_transaction_lines.first
    complete_linked_return!(original_line: original_line, quantity: 1)

    other = pos_open_context(
      store: @store,
      actor: @actor,
      register: Register.create!(store: @store, register_number: 2, name: "Lane 2")
    )
    transaction = Pos::StartTransaction.call(session: other[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::AddLinkedReturnLine.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        original_line: original_line,
        quantity: 1,
        reason_code: "changed_mind"
      )
    end
    assert_match(/remaining quantity/, error.message)
  end

  test "Cash refund lowers expected Cash without going negative" do
    other = pos_open_context(
      store: @store,
      actor: @actor,
      register: Register.create!(store: @store, register_number: 9, name: "Origin")
    )
    original = complete_quantity_sale!(quantity: 1, session: other[:session])
    original_line = original.pos_transaction_lines.first
    complete_linked_return!(original_line: original_line, quantity: 1)

    totals = Pos::SessionTotals.for(@context[:session].reload)
    assert totals.cash_refund_cents.positive?
    expected = totals.expected_cash_cents
    assert_operator expected, :>=, 0
    assert_equal 50_000 - totals.cash_refund_cents, expected

    session = pos_close_session!(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].reload.lock_version,
      closing_count_cents: expected
    )
    assert_equal expected, session.closing_expected_cash_cents
    assert_equal 0, session.closing_variance_cents

    period = Pos::FinalizeReportingPeriod.call(
      period: @context[:period],
      actor: @actor,
      expected_lock_version: @context[:period].reload.lock_version
    )
    z = Pos::PeriodTotals.for(period)
    assert_equal expected, z.closing_expected_cash_cents_sum
    assert z.return_total_cents.positive?
    assert_not_nil period.finalized_cash_refund_cents
    assert period.finalized_cash_refund_cents.positive?
    assert_equal totals.cash_refund_cents, period.finalized_cash_refund_cents
  end

  test "headless mixed sale plus return settles positive negative and zero signed nets" do
    original_small = complete_quantity_sale!(quantity: 1)
    original_large = complete_quantity_sale!(quantity: 2)

    positive = mixed_transaction(
      sale_quantity: 2,
      original_line: original_small.pos_transaction_lines.first,
      return_quantity: 1
    )
    assert_equal :payment, Pos::Support.settlement_direction(positive)
    assert positive.signed_net_cents.positive?
    Pos::TenderCash.call(
      transaction: positive,
      actor: @actor,
      expected_lock_version: positive.lock_version,
      amount_presented_cents: positive.signed_net_cents
    )
    completed_positive = complete_current!(positive.reload)
    assert_equal completed_positive.transaction.total_cents, completed_positive.transaction.signed_net_cents
    assert_equal "payment", completed_positive.operation.envelope.dig("tenders", 0, "direction")

    negative = mixed_transaction(
      sale_quantity: 1,
      original_line: original_large.pos_transaction_lines.first,
      return_quantity: 2
    )
    assert_equal :refund, Pos::Support.settlement_direction(negative)
    assert negative.signed_net_cents.negative?
    error = assert_raises(Pos::Error) do
      Pos::TenderCash.call(
        transaction: negative,
        actor: @actor,
        expected_lock_version: negative.lock_version,
        amount_presented_cents: negative.total_cents
      )
    end
    assert_match(/does not require payment/, error.message)
    Pos::AddRefundTender.call(
      transaction: negative.reload,
      actor: @actor,
      expected_lock_version: negative.lock_version,
      tender_type: @cash,
      amount_cents: -negative.signed_net_cents
    )
    completed_negative = complete_current!(negative.reload, expected_signed_net_cents: negative.signed_net_cents)
    assert_equal(-completed_negative.transaction.total_cents, completed_negative.transaction.signed_net_cents)
    assert_equal "refund", completed_negative.operation.envelope.dig("tenders", 0, "direction")

    even_original = complete_quantity_sale!(quantity: 1)
    even = mixed_transaction(
      sale_quantity: 1,
      original_line: even_original.pos_transaction_lines.first,
      return_quantity: 1
    )
    assert_equal :none, Pos::Support.settlement_direction(even)
    assert_equal 0, even.signed_net_cents
    assert_equal 0, even.total_cents
    assert even.pos_tenders.empty?
    completed_even = complete_current!(even.reload, expected_signed_net_cents: 0)
    assert_equal 0, completed_even.transaction.signed_net_cents
    assert_empty completed_even.operation.envelope.fetch("tenders")
  end

  test "pre-6.5 failed and stale in-flight sale completions recover against the new command shape" do
    transaction = start_sale_with_cash
    operation_id = SecureRandom.uuid_v7
    legacy = {
      "transaction_id" => transaction.id.to_s,
      "operation_id" => operation_id,
      "expected_lock_version" => transaction.lock_version,
      "expected_total_cents" => transaction.total_cents
    }
    PosOperation.create!(
      id: operation_id,
      command_type: PosOperation::COMMAND_TYPE,
      source_id: transaction.register_id,
      idempotency_key: operation_id,
      command_payload_hash: Idempotency::CanonicalJson.hash(legacy),
      status: "failed",
      store_id: transaction.store_id,
      register_id: transaction.register_id,
      pos_transaction_id: transaction.id
    )

    result = Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.total_cents
    )
    assert result.transaction.completed?
    assert_equal operation_id, result.operation.id
    assert_equal Idempotency::CanonicalJson.hash(legacy), result.operation.command_payload_hash
  end

  test "pre-6.5 stale in-flight sale completion can be reclaimed" do
    transaction = start_sale_with_cash
    operation_id = SecureRandom.uuid_v7
    legacy = {
      "transaction_id" => transaction.id.to_s,
      "operation_id" => operation_id,
      "expected_lock_version" => transaction.lock_version,
      "expected_total_cents" => transaction.total_cents
    }
    PosOperation.create!(
      id: operation_id,
      command_type: PosOperation::COMMAND_TYPE,
      source_id: transaction.register_id,
      idempotency_key: operation_id,
      command_payload_hash: Idempotency::CanonicalJson.hash(legacy),
      status: "in_flight",
      lease_expires_at: 1.hour.ago,
      store_id: transaction.store_id,
      register_id: transaction.register_id,
      pos_transaction_id: transaction.id
    )

    result = Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    assert result.transaction.completed?
  end

  test "pre-6.5 operation with a different expected total is still rejected" do
    transaction = start_sale_with_cash
    operation_id = SecureRandom.uuid_v7
    legacy = {
      "transaction_id" => transaction.id.to_s,
      "operation_id" => operation_id,
      "expected_lock_version" => transaction.lock_version,
      "expected_total_cents" => 1
    }
    PosOperation.create!(
      id: operation_id,
      command_type: PosOperation::COMMAND_TYPE,
      source_id: transaction.register_id,
      idempotency_key: operation_id,
      command_payload_hash: Idempotency::CanonicalJson.hash(legacy),
      status: "failed",
      store_id: transaction.store_id,
      register_id: transaction.register_id,
      pos_transaction_id: transaction.id
    )

    assert_raises(Pos::PayloadMismatch) do
      Pos::CompleteTransaction.call(
        transaction: transaction,
        actor: @actor,
        operation_id: operation_id,
        expected_lock_version: transaction.lock_version,
        expected_total_cents: transaction.total_cents
      )
    end
    assert transaction.reload.working?
  end

  test "controlled actions reject return-direction lines" do
    original = complete_quantity_sale!(quantity: 1)
    working = start_return_transaction
    line = Pos::AddLinkedReturnLine.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      original_line: original.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    error = assert_raises(Pos::Error) do
      Pos::ExecuteControlledAction.call(
        transaction: working.reload,
        line: line,
        actor: @actor,
        expected_lock_version: working.lock_version,
        action_type: "price_override",
        operation: "apply",
        reason_code: "damaged",
        selling_unit_price_cents: 100
      )
    end
    assert_match(/sale-direction only/, error.message)
  end

  test "Cash allows_refund cannot be disabled" do
    @cash.allows_refund = false
    assert_not @cash.valid?
    assert_includes @cash.errors[:allows_refund], "must remain true for Cash"
  end

  test "omitting expected_signed_net_cents on a return-only basket fails before leasing" do
    original = complete_quantity_sale!(quantity: 1)
    transaction = start_return_transaction
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @cash,
      amount_cents: -transaction.signed_net_cents
    )
    transaction.reload
    refute_equal transaction.signed_net_cents, transaction.total_cents
    operation_count = PosOperation.count

    error = assert_raises(Pos::Error) do
      Pos::CompleteTransaction.call(
        transaction: transaction,
        actor: @actor,
        operation_id: SecureRandom.uuid_v7,
        expected_lock_version: transaction.lock_version,
        expected_total_cents: transaction.total_cents
      )
    end

    assert_match(/expected signed net is required/, error.message)
    assert_equal operation_count, PosOperation.count
    assert transaction.reload.working?
  end

  test "linked return fails closed when the original depletion is missing" do
    original = complete_quantity_sale!(quantity: 1)
    original_line = original.pos_transaction_lines.first
    InventoryValuationEntry.where(
      source_type: "PosTransactionLine",
      source_id: original_line.id,
      entry_type: "depletion"
    ).delete_all
    working = start_return_transaction

    error = assert_raises(Pos::Error) do
      Pos::AddLinkedReturnLine.call(
        transaction: working,
        actor: @actor,
        expected_lock_version: working.lock_version,
        original_line: original_line,
        quantity: 1,
        reason_code: "changed_mind"
      )
    end
    assert_match(/inventory valuation is missing/, error.message)
  end

  test "linked return fails closed when the original depletion increases value" do
    original = complete_quantity_sale!(quantity: 1)
    original_line = original.pos_transaction_lines.first
    InventoryValuationEntry.where(
      source_type: "PosTransactionLine",
      source_id: original_line.id,
      entry_type: "depletion"
    ).update_all(value_delta_cents: 50)
    working = start_return_transaction

    error = assert_raises(Pos::Error) do
      Pos::AddLinkedReturnLine.call(
        transaction: working,
        actor: @actor,
        expected_lock_version: working.lock_version,
        original_line: original_line,
        quantity: 1,
        reason_code: "changed_mind"
      )
    end
    assert_match(/inventory valuation is malformed/, error.message)
  end

  test "zero-value sale and linked return mutations advance lock_version" do
    @variant.update!(regular_price_cents: 0)
    sale = Pos::StartTransaction.call(session: open_session, actor: @actor)
    before_add = sale.lock_version
    Pos::AddMerchandise.call(
      transaction: sale,
      actor: @actor,
      expected_lock_version: sale.lock_version,
      identifier: @variant.sku,
      quantity: 2
    )
    sale.reload
    assert_operator sale.lock_version, :>, before_add
    assert_equal 0, sale.total_cents
    assert_equal 0, sale.signed_net_cents

    original_line = complete_current!(sale).transaction.pos_transaction_lines.first
    working = start_return_transaction
    before_return = working.lock_version
    line = Pos::AddLinkedReturnLine.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      original_line: original_line,
      quantity: 1,
      reason_code: "changed_mind"
    )
    working.reload
    assert_operator working.lock_version, :>, before_return
    assert_equal 0, working.total_cents
    assert_equal 0, working.signed_net_cents

    before_quantity = working.lock_version
    Pos::ChangeQuantity.call(
      transaction: working,
      line: line,
      actor: @actor,
      expected_lock_version: working.lock_version,
      quantity: 2
    )
    working.reload
    assert_operator working.lock_version, :>, before_quantity

    before_remove = working.lock_version
    Pos::RemoveWorkingLine.call(
      transaction: working,
      line: line,
      actor: @actor,
      expected_lock_version: working.lock_version
    )
    working.reload
    assert_operator working.lock_version, :>, before_remove
  end

  test "linked non-inventory return completes without inventory effects" do
    service = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      name: "Store Service"
    )
    transaction = Pos::StartTransaction.call(session: open_session, actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: service.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    original_line = complete_current!(transaction.reload).transaction.pos_transaction_lines.first
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: original_line.id).count

    result = complete_linked_return!(original_line: original_line, quantity: 1)
    return_line = result.transaction.pos_transaction_lines.first
    assert result.transaction.completed?
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: return_line.id).count
    assert_equal 0, InventoryValuationEntry.where(source_type: "PosTransactionLine", source_id: return_line.id).count
    assert_nil InventoryBalance.find_by(store: @store, product_variant: service)
    assert_equal 0, OutboxMessage.where(event_type: "inventory.return_posted").count
    Pos::CompletedTransactionFacts.new(result.operation.envelope).verify!
  end

  test "linked return copies the original snapshot after the variant is discontinued" do
    original = complete_quantity_sale!(quantity: 1)
    original_line = original.pos_transaction_lines.first
    snapshot = original_line.merchandise_snapshot
    variant = original_line.product_variant
    variant.update!(status: "discontinued")
    variant.product.update!(status: "discontinued")
    refute variant.reload.sellable?

    result = complete_linked_return!(original_line: original_line, quantity: 1)
    return_line = result.transaction.pos_transaction_lines.first
    assert result.transaction.completed?
    assert_equal snapshot, return_line.merchandise_snapshot
    assert_equal variant.id, return_line.product_variant_id
  end

  test "exact_settlement is false when applied tenders exceed signed net" do
    original = complete_quantity_sale!(quantity: 1)
    working = start_return_transaction
    Pos::AddLinkedReturnLine.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      original_line: original.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    working.reload
    Pos::AddRefundTender.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      tender_type: @cash,
      amount_cents: -working.signed_net_cents
    )
    working.reload
    assert Pos::Support.exact_settlement?(working)
    assert_equal 0, Pos::Support.remaining_refund_cents(working)

    working.pos_tenders.first.update_columns(amount_cents: working.pos_tenders.first.amount_cents + 1)
    working.reload
    assert_equal 0, Pos::Support.remaining_refund_cents(working)
    assert_not Pos::Support.exact_settlement?(working)
  end

  private

  def start_sale_with_cash(quantity: 1, session: open_session)
    transaction = Pos::StartTransaction.call(session: session, actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: quantity
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
  end

  def complete_quantity_sale!(quantity:, discount_basis_points: nil, session: open_session)
    transaction = start_sale_with_cash(quantity: quantity, session: session)
    if discount_basis_points
      Pos::ExecuteControlledAction.call(
        transaction: transaction,
        line: transaction.pos_transaction_lines.first,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        action_type: "line_discount",
        operation: "apply",
        reason_code: "customer_service",
        discount_basis_points: discount_basis_points
      )
      transaction.reload
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: transaction.total_cents
      )
      transaction.reload
    end
    complete_current!(transaction).transaction
  end

  def complete_unit_sale!(unit)
    transaction = Pos::StartTransaction.call(session: open_session, actor: @actor)
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
    complete_current!(transaction.reload).transaction
  end

  def start_return_transaction
    Pos::StartTransaction.call(session: open_session, actor: @actor)
  end

  def complete_linked_return!(original_line:, quantity:)
    transaction = start_return_transaction
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original_line,
      quantity: quantity,
      reason_code: "changed_mind"
    )
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @cash,
      amount_cents: -transaction.signed_net_cents
    )
    complete_current!(transaction.reload, expected_signed_net_cents: transaction.signed_net_cents)
  end

  def mixed_transaction(sale_quantity:, original_line:, return_quantity:)
    transaction = start_return_transaction
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: sale_quantity
    )
    transaction.reload
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original_line,
      quantity: return_quantity,
      reason_code: "wrong_item"
    )
    transaction.reload
  end

  def complete_current!(transaction, expected_signed_net_cents: transaction.total_cents)
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: expected_signed_net_cents
    )
  end

  def open_session
    session = @context[:session]
    return session if session.reload.open?

    @context = pos_open_context(
      store: @store,
      actor: @actor,
      register: @context[:register],
      opening_float_cents: 0
    )
    @context[:session]
  end
end
