# frozen_string_literal: true

require "test_helper"

class PosReturnsMixedTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @food = tax_class(code: "prepared_food", name: "Prepared food")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true, @food.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 40, unit_cost_cents: 100)
    @thirty, @twenty = priced_variants(3000, 2000)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 50_000)
    Pos::TenderTypes.seed!
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
    @check = TenderType.find_by!(code: "check")
    @check.update!(allows_refund: true)
    @other = TenderType.create!(
      code: "campus_charge_65d",
      name: "Campus Charge",
      behavioral_category: "other",
      external_reference_policy: "required",
      allows_refund: true,
      active: true
    )
  end

  test "sale plus unlinked settles positive negative and zero nets" do
    positive = complete_sale_and_unlinked!(sale: @thirty, unlinked: @twenty)
    assert_directional_arithmetic!(positive.transaction)
    assert_equal 1000, positive.transaction.signed_net_cents
    assert_equal :payment, Pos::Support.settlement_direction(positive.transaction)
    assert(positive.transaction.pos_tenders.all? { |tender| tender.direction == "payment" })
    refute positive.transaction.even_exchange?
    Pos::CompletedTransactionFacts.new(positive.operation.envelope).verify!

    negative = complete_sale_and_unlinked!(sale: @twenty, unlinked: @thirty)
    assert_directional_arithmetic!(negative.transaction)
    assert_equal(-1000, negative.transaction.signed_net_cents)
    assert(negative.transaction.pos_tenders.all? { |tender| tender.direction == "refund" })
    Pos::CompletedTransactionFacts.new(negative.operation.envelope).verify!

    even = complete_sale_and_unlinked!(sale: @twenty, unlinked: @twenty)
    assert_directional_arithmetic!(even.transaction)
    assert_equal 0, even.transaction.signed_net_cents
    assert_equal 0, even.transaction.pos_tenders.count
    assert even.transaction.even_exchange?
    assert_empty even.operation.envelope.fetch("tenders")
    Pos::CompletedTransactionFacts.new(even.operation.envelope).verify!
  end

  test "sale plus linked settles positive negative and zero nets" do
    original_small = complete_priced_sale!(@twenty)
    original_large = complete_priced_sale!(@thirty)
    original_even = complete_priced_sale!(@twenty)

    positive = complete_sale_and_linked!(sale: @thirty, original_line: original_small.pos_transaction_lines.first)
    assert_directional_arithmetic!(positive.transaction)
    assert positive.transaction.signed_net_cents.positive?
    refute positive.transaction.even_exchange?

    negative = complete_sale_and_linked!(sale: @twenty, original_line: original_large.pos_transaction_lines.first)
    assert_directional_arithmetic!(negative.transaction)
    assert negative.transaction.signed_net_cents.negative?

    even = complete_sale_and_linked!(sale: @twenty, original_line: original_even.pos_transaction_lines.first)
    assert_equal 0, even.transaction.signed_net_cents
    assert even.transaction.even_exchange?
    assert_equal 0, even.transaction.pos_tenders.count
  end

  test "sale linked and unlinked complete on one basket" do
    original = complete_priced_sale!(@twenty)
    transaction = start_transaction
    add_sale!(transaction, @thirty)
    add_linked!(transaction, original.pos_transaction_lines.first)
    add_unlinked!(transaction, @twenty, requested_cents: 2000)
    result = settle_and_complete!(transaction.reload)
    txn = result.transaction
    assert_equal 3, txn.pos_transaction_lines.count
    assert txn.pos_transaction_lines.any?(&:sale?)
    assert txn.pos_transaction_lines.any?(&:linked_return?)
    assert txn.pos_transaction_lines.any?(&:unlinked_return?)
    assert_directional_arithmetic!(txn)
    Pos::CompletedTransactionFacts.new(result.operation.envelope).verify!
  end

  test "linked plus unlinked without a sale completes as a refund" do
    original = complete_priced_sale!(@twenty)
    transaction = start_transaction
    add_linked!(transaction, original.pos_transaction_lines.first)
    add_unlinked!(transaction, @thirty, requested_cents: 3000)
    result = settle_and_complete!(transaction.reload)
    assert result.transaction.pos_transaction_lines.none?(&:sale?)
    assert result.transaction.signed_net_cents.negative?
    assert_directional_arithmetic!(result.transaction)
  end

  test "unlinked price variance never leaks into discount totals" do
    transaction = start_transaction
    add_sale!(transaction, @thirty)
    add_unlinked!(transaction, @twenty, requested_cents: 1500)
    result = settle_and_complete!(transaction.reload)
    txn = result.transaction
    unlinked = txn.pos_transaction_lines.find(&:unlinked_return?)
    assert_equal 0, txn.discount_cents
    assert_equal 0, txn.return_discount_cents
    assert_equal 0, unlinked.manual_discount_cents
    assert_nil unlinked.manual_discount_basis_points
    envelope = result.operation.envelope
    unlinked_fact = envelope.fetch("lines").find { |line| line["original_transaction_line_id"].blank? && line["direction"] == "return" }
    assert unlinked_fact.key?("return_price_adjustment")
    refute unlinked_fact.key?("discount")
    refute envelope.fetch("transaction").fetch("discount_cents").positive? if envelope.fetch("transaction").key?("discount_cents")
  end

  test "positive net rejects refunds and accepts each payment identity" do
    transaction = start_transaction
    add_sale!(transaction, @thirty)
    add_unlinked!(transaction, @twenty, requested_cents: 2000)
    transaction.reload
    error = assert_raises(Pos::Error) do
      Pos::AddRefundTender.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @cash,
        amount_cents: transaction.signed_net_cents
      )
    end
    assert_match(/does not require a refund/, error.message)
    cancel_working!(transaction)

    {
      cash: ->(txn) { cash_payment!(txn, txn.signed_net_cents) },
      card: ->(txn) { add_payment!(txn, @card, txn.signed_net_cents, "AUTH-POS") },
      check: ->(txn) { add_payment!(txn, @check, txn.signed_net_cents, "CK-1") },
      other: ->(txn) { add_payment!(txn, @other, txn.signed_net_cents, "PO-1") }
    }.each_value do |settle|
      txn = start_transaction
      add_sale!(txn, @thirty)
      add_unlinked!(txn, @twenty, requested_cents: 2000)
      settle.call(txn.reload)
      completed = complete_current!(txn.reload)
      assert(completed.transaction.pos_tenders.all? { |tender| tender.direction == "payment" })
    end

    split = start_transaction
    add_sale!(split, @thirty)
    add_unlinked!(split, @twenty, requested_cents: 2000)
    split.reload
    add_payment!(split, @card, 400, "AUTH-SPLIT")
    cash_payment!(split.reload, split.signed_net_cents - 400)
    completed = complete_current!(split.reload)
    assert_equal 2, completed.transaction.pos_tenders.count
    assert_equal completed.transaction.signed_net_cents, completed.transaction.pos_tenders.sum(:amount_cents)
  end

  test "negative net rejects payments and accepts split refunds" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    add_unlinked!(transaction, @thirty, requested_cents: 3000)
    transaction.reload
    error = assert_raises(Pos::Error) do
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: transaction.total_cents
      )
    end
    assert_match(/does not require payment/, error.message)
    cancel_working!(transaction)

    [
      [ @cash, nil ],
      [ @card, "REF-CARD" ],
      [ @check, "REF-CK" ],
      [ @other, "PO-R" ]
    ].each do |type, reference|
      txn = start_transaction
      add_sale!(txn, @twenty)
      add_unlinked!(txn, @thirty, requested_cents: 3000)
      add_refund!(txn.reload, type, -txn.signed_net_cents, reference)
      completed = complete_current!(txn.reload)
      assert(completed.transaction.pos_tenders.all? { |tender| tender.direction == "refund" })
    end

    split = start_transaction
    add_sale!(split, @twenty)
    add_unlinked!(split, @thirty, requested_cents: 3000)
    due = -split.reload.signed_net_cents
    card_refund_before = Pos::SessionTotals.for(@context[:session].reload).card_refund_cents
    add_refund!(split, @card, 400, "REF-HALF")
    add_refund!(split.reload, @cash, due - 400)
    completed = complete_current!(split.reload)
    assert_equal 2, completed.transaction.pos_tenders.count
    assert_equal due, completed.transaction.pos_tenders.sum(:amount_cents)
    totals = Pos::SessionTotals.for(@context[:session].reload)
    assert_equal card_refund_before + 400, totals.card_refund_cents
    assert totals.cash_refund_cents.positive?
    assert_equal(
      @context[:session].opening_float_cents + totals.cash_payment_cents - totals.cash_refund_cents,
      totals.expected_cash_cents
    )
  end

  test "zero net mixed basket rejects tenders" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    add_unlinked!(transaction, @twenty, requested_cents: 2000)
    transaction.reload
    error = assert_raises(Pos::Error) do
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: 2000
      )
    end
    assert_match(/does not require payment/, error.message)
    error = assert_raises(Pos::Error) do
      Pos::AddRefundTender.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @cash,
        amount_cents: 2000
      )
    end
    assert_match(/does not require a refund/, error.message)
    completed = complete_current!(transaction.reload)
    assert_equal 0, completed.transaction.pos_tenders.count
  end

  test "basket mutations clear working tenders when signed net changes sign" do
    transaction = start_transaction
    add_sale!(transaction, @thirty)
    cash_payment!(transaction.reload, transaction.signed_net_cents)
    assert_equal 1, transaction.reload.pos_tenders.count
    add_unlinked!(transaction.reload, @thirty, requested_cents: 4000)
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert_equal :refund, Pos::Support.settlement_direction(transaction)
    cancel_working!(transaction)

    transaction = start_transaction
    add_unlinked!(transaction, @thirty, requested_cents: 3000)
    add_refund!(transaction.reload, @cash, -transaction.signed_net_cents)
    assert_equal 1, transaction.reload.pos_tenders.count
    add_sale!(transaction.reload, @thirty)
    add_sale!(transaction.reload, @twenty)
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert_equal :payment, Pos::Support.settlement_direction(transaction)
    cancel_working!(transaction)

    transaction = start_transaction
    add_sale!(transaction, @twenty)
    cash_payment!(transaction.reload, transaction.signed_net_cents)
    add_unlinked!(transaction.reload, @twenty, requested_cents: 2000)
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert_equal :none, Pos::Support.settlement_direction(transaction)
    assert transaction.even_exchange?
  end

  test "mixed basket keeps sale linked and unlinked mutation rules" do
    original = complete_quantity_sale!(quantity: 2)
    transaction = start_transaction
    sale_line = add_sale!(transaction, @variant)
    linked = add_linked!(transaction.reload, original.pos_transaction_lines.first)
    unlinked = add_unlinked!(transaction.reload, @twenty, requested_cents: 2000)

    Pos::ChangeQuantity.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      quantity: 2
    )
    assert_equal 2, sale_line.reload.quantity

    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "price_override",
      operation: "apply",
      reason_code: "shelf_price_mismatch",
      selling_unit_price_cents: 1800
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "price_override",
      operation: "remove"
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "tax_class_override",
      operation: "apply",
      reason_code: "classification_correction",
      tax_class_id: @food.id
    )

    Pos::ChangeQuantity.call(
      transaction: transaction.reload,
      line: linked.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      quantity: 1
    )
    assert_equal 1, linked.reload.quantity

    error = assert_raises(Pos::Error) do
      Pos::ExecuteControlledAction.call(
        transaction: transaction.reload,
        line: linked.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        action_type: "price_override",
        operation: "apply",
        reason_code: "shelf_price_mismatch",
        selling_unit_price_cents: 1
      )
    end
    assert_match(/sale-direction only/, error.message)

    error = assert_raises(Pos::Error) do
      Pos::ChangeQuantity.call(
        transaction: transaction.reload,
        line: unlinked.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        quantity: 2
      )
    end
    assert_match(/unlinked returns cannot change quantity/, error.message)

    assert linked.reload.linked_return?
    assert unlinked.reload.unlinked_return?
    assert_nil unlinked.original_transaction_line_id
  end

  test "mixed inventory posts sale return used and skips non-inventory" do
    non_inventory = pos_sellable_variant(
      actor: @actor,
      tax_class: @tax,
      inventory_mode: "non_inventory",
      name: "Gift Wrap"
    )
    sale_used_variant, sale_unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Sale")
    linked_used_variant, linked_unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Linked")
    unlinked_used_variant, unlinked_unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Unlinked")
    linked_used_sale = complete_unit_sale!(linked_unit)
    complete_unit_sale!(unlinked_unit)
    original_qty = complete_quantity_sale!(quantity: 1)
    qty_before = InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity

    transaction = start_transaction
    sale_line = add_sale!(transaction, @variant, quantity: 2)
    add_sale!(transaction.reload, non_inventory)
    add_sale!(transaction.reload, sale_unit)
    add_linked!(transaction.reload, original_qty.pos_transaction_lines.first)
    add_linked!(transaction.reload, linked_used_sale.pos_transaction_lines.first)
    add_unlinked!(transaction.reload, @twenty, quantity: 3, requested_cents: 2000)
    add_unlinked!(transaction.reload, unlinked_unit, requested_cents: 1200)
    result = settle_and_complete!(transaction.reload)
    txn = result.transaction

    sale_ledger = InventoryLedgerEntry.find_by!(source_type: "PosTransactionLine", source_id: sale_line.id)
    assert_equal(-2, sale_ledger.quantity_delta)
    assert_equal qty_before - 2 + 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity

    linked_qty_line = txn.pos_transaction_lines.find { |line| line.linked_return? && line.inventory_unit_id.nil? }
    linked_qty_valuation = InventoryValuationEntry.find_by!(source_type: "PosTransactionLine", source_id: linked_qty_line.id)
    original_depletion = InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: original_qty.pos_transaction_lines.first.id,
      entry_type: "depletion"
    )
    assert_equal(-original_depletion.value_delta_cents, linked_qty_valuation.value_delta_cents)

    unlinked_qty = txn.pos_transaction_lines.find { |line| line.unlinked_return? && line.inventory_unit_id.nil? }
    unlinked_outbox = OutboxMessage.find_by!(event_type: "inventory.return_posted", aggregate_id: unlinked_qty.id)
    assert_equal false, unlinked_outbox.payload["linked"]
    assert unlinked_outbox.payload["valuation_basis"].present?

    assert sale_unit.reload.removed?
    assert linked_unit.reload.on_hand?
    assert unlinked_unit.reload.on_hand?
    assert_equal 500, unlinked_unit.carrying_value_cents

    non_inventory_line = txn.pos_transaction_lines.find { |line| line.product_variant_id == non_inventory.id }
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: non_inventory_line.id).count
    assert_equal 0, OutboxMessage.where(event_type: "inventory.sale_posted", aggregate_id: non_inventory_line.id).count

    txn.pos_transaction_lines.each do |line|
      next if line.product_variant.derived_inventory_tracking == "non_inventory"

      ledger = InventoryLedgerEntry.find_by(source_type: "PosTransactionLine", source_id: line.id)
      next if ledger.nil?

      assert_equal line.id, ledger.source_id
    end
    assert_empty Inventory::LedgerPairIntegrity.drifts(store_id: @store.id)
    assert_equal sale_used_variant.id, sale_unit.product_variant_id
    assert_equal linked_used_variant.id, linked_unit.product_variant_id
    assert_equal unlinked_used_variant.id, unlinked_unit.product_variant_id
  end

  test "replay of mixed cash and card refund does not duplicate facts" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    add_unlinked!(transaction, @thirty, requested_cents: 3000)
    due = -transaction.reload.signed_net_cents
    add_refund!(transaction, @card, 400, "REF-R")
    add_refund!(transaction.reload, @cash, due - 400)
    transaction.reload
    operation_id = SecureRandom.uuid_v7
    args = {
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    }
    first = Pos::CompleteTransaction.call(**args)
    second = Pos::CompleteTransaction.call(**args)
    assert second.replayed
    assert_equal first.transaction.id, second.transaction.id
    assert_equal first.operation.envelope_hash, second.operation.envelope_hash
    assert_equal 1, PosTransaction.completed.where(id: first.transaction.id).count
    assert_equal 2, first.transaction.pos_tenders.count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed", aggregate_id: first.transaction.id).count
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: first.transaction.pos_transaction_lines.find(&:sale?).id).count
    assert_equal 1, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: first.transaction.pos_transaction_lines.find(&:unlinked_return?).id).count
  end

  test "changed signed net on the same operation id is a payload mismatch" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    add_unlinked!(transaction, @thirty, requested_cents: 3000)
    add_refund!(transaction.reload, @cash, -transaction.signed_net_cents)
    transaction.reload
    operation_id = SecureRandom.uuid_v7
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    )
    assert_raises(Pos::PayloadMismatch) do
      Pos::CompleteTransaction.call(
        transaction: transaction.reload,
        actor: @actor,
        operation_id: operation_id,
        expected_lock_version: transaction.lock_version,
        expected_total_cents: transaction.total_cents,
        expected_signed_net_cents: transaction.signed_net_cents - 1
      )
    end
  end

  test "FindCompletionOperation recovers a failed mixed refund lease" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    add_unlinked!(transaction, @thirty, requested_cents: 3000)
    add_refund!(transaction.reload, @cash, -transaction.signed_net_cents)
    transaction.reload
    payload = Pos::CompleteTransaction.command_payload(
      transaction: transaction,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    )
    operation_id = payload.fetch("operation_id")
    Pos::OperationLease.begin!(
      register_id: transaction.register_id,
      operation_id: operation_id,
      command_payload: payload,
      store_id: transaction.store_id,
      pos_transaction_id: transaction.id
    )
    PosOperation.find(operation_id).update!(status: "failed", lease_expires_at: nil)
    found = Pos::FindCompletionOperation.call(transaction: transaction.reload, actor: @actor)
    assert_equal operation_id, found.id
  end

  test "even exchange replay keeps zero tenders" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    add_unlinked!(transaction, @twenty, requested_cents: 2000)
    transaction.reload
    operation_id = SecureRandom.uuid_v7
    args = {
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: 0,
      expected_signed_net_cents: 0
    }
    first = Pos::CompleteTransaction.call(**args)
    second = Pos::CompleteTransaction.call(**args)
    assert second.replayed
    assert_equal 0, first.transaction.pos_tenders.count
  end

  test "completion failure after a corrupted unlinked fact rolls back" do
    transaction = start_transaction
    add_sale!(transaction, @twenty)
    line = add_unlinked!(transaction.reload, @thirty, requested_cents: 3000)
    add_refund!(transaction.reload, @cash, -transaction.signed_net_cents)
    line.pos_controlled_actions.delete_all
    error = assert_raises(Pos::Error) { complete_current!(transaction.reload) }
    assert_match(/unlinked_return fact/, error.message)
    assert transaction.reload.working?
    assert_nil transaction.receipt_sequence
    assert_equal 0, OutboxMessage.where(event_type: "pos.transaction_completed").count
    assert_equal 0, InventoryLedgerEntry.where(source_type: "PosTransactionLine", source_id: line.id).count
    assert_equal 1, transaction.pos_tenders.count
  end

  test "sale controls plus unlinked fact complete and reject the wrong attachments" do
    original = complete_quantity_sale!(quantity: 1)
    transaction = start_transaction
    sale_line = add_sale!(transaction, @variant)
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "price_override",
      operation: "apply",
      reason_code: "shelf_price_mismatch",
      selling_unit_price_cents: 1800
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "price_override",
      operation: "remove"
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "customer_service",
      discount_basis_points: 1000
    )
    Pos::ExecuteControlledAction.call(
      transaction: transaction.reload,
      line: sale_line.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      action_type: "tax_class_override",
      operation: "apply",
      reason_code: "classification_correction",
      tax_class_id: @food.id
    )
    unlinked = add_unlinked!(transaction.reload, @twenty, requested_cents: 1800)
    linked = add_linked!(transaction.reload, original.pos_transaction_lines.first)
    result = settle_and_complete!(transaction.reload)
    envelope = result.operation.envelope
    Pos::CompletedTransactionFacts.new(envelope).verify!
    actions = envelope.fetch("controlled_actions").map { |action| action["action"] }
    assert_includes actions, "line_discount"
    assert_includes actions, "tax_class_override"
    assert_includes actions, "unlinked_return"
    refute_includes actions, "price_override"
    assert_equal 0, linked.reload.pos_controlled_actions.count
    assert_equal 1, unlinked.reload.pos_controlled_actions.where(action_type: "unlinked_return").count
  end

  test "session close and two-session z capture mixed sales returns and tenders" do
    complete_sale_and_unlinked!(sale: @thirty, unlinked: @twenty)
    original = complete_priced_sale!(@twenty)
    linked_txn = start_transaction
    add_linked!(linked_txn, original.pos_transaction_lines.first)
    settle_and_complete!(linked_txn.reload)
    even = complete_sale_and_unlinked!(sale: @twenty, unlinked: @twenty)
    assert even.transaction.even_exchange?

    totals = Pos::SessionTotals.for(@context[:session].reload)
    expected = @context[:session].opening_float_cents + totals.cash_payment_cents - totals.cash_refund_cents
    assert_equal expected, totals.expected_cash_cents
    session = pos_close_session!(
      session: @context[:session],
      actor: @actor,
      closing_count_cents: 0
    )
    assert_equal expected, session.closing_expected_cash_cents
    assert_equal 0 - expected, session.closing_variance_cents

    period = @context[:period]
    second_session = Pos::OpenSession.call(
      store: @store,
      register: @context[:register],
      actor: @actor,
      reporting_period: period,
      opening_float_cents: 0
    )
    @context = @context.merge(session: second_session)
    unlinked_only = start_transaction
    add_unlinked!(unlinked_only, @thirty, requested_cents: 3000)
    add_refund!(unlinked_only.reload, @card, -unlinked_only.signed_net_cents, "Z-CARD")
    complete_current!(unlinked_only.reload)
    pos_close_session!(
      session: second_session,
      actor: @actor,
      closing_count_cents: 0
    )

    period = Pos::FinalizeReportingPeriod.call(
      period: period.reload,
      actor: @actor,
      expected_lock_version: period.lock_version
    )
    z = Pos::PeriodTotals.for(period)
    sale_direction_total = z.subtotal_cents - z.discount_cents + z.tax_cents
    assert_equal sale_direction_total, period.finalized_total_cents
    assert period.finalized_return_total_cents.positive?
    assert_equal z.net_cents, period.finalized_net_cents
    assert period.finalized_card_refund_cents.positive?
    assert_equal 2, period.finalized_session_count

    snapshot_subtotal = period.finalized_subtotal_cents
    snapshot_total = period.finalized_total_cents
    @thirty.update_columns(regular_price_cents: 1)
    @thirty.product.update!(name: "Renamed after Z")
    z_after = Pos::PeriodTotals.for(period.reload)
    assert_equal snapshot_subtotal, z_after.subtotal_cents
    assert_equal snapshot_total, z_after.total_cents
    assert_equal period.finalized_subtotal_cents, z_after.subtotal_cents
  end

  test "pre-6.5 finalized additive columns stay null" do
    unused = Pos::OpenReportingPeriod.call(
      store: @store,
      register: Register.create!(store: @store, register_number: 77, name: "Legacy"),
      actor: @actor
    )
    Pos::FinalizeReportingPeriod.call(period: unused, actor: @actor, expected_lock_version: unused.lock_version)
    PosReportingPeriod.where(id: unused.id).update_all(
      finalized_return_total_cents: nil,
      finalized_net_cents: nil,
      finalized_cash_refund_cents: nil
    )
    unused.reload
    assert_nil unused.finalized_return_total_cents
    assert_nil unused.finalized_net_cents
    assert_nil unused.finalized_cash_refund_cents
  end

  test "unlinked remaining quantity does not consume linked returnability" do
    original = complete_quantity_sale!(quantity: 2)
    original_line = original.pos_transaction_lines.first
    transaction = start_transaction
    add_unlinked!(transaction, @variant, quantity: 2, requested_cents: @variant.regular_price_cents)
    settle_and_complete!(transaction.reload)
    assert_equal 2, Pos::Returnability.remaining_quantity(original_line)
  end

  test "mixed completion audits and posts inventory outbox once per tracked line" do
    transaction = start_transaction
    sale_line = add_sale!(transaction, @thirty)
    unlinked = add_unlinked!(transaction.reload, @twenty, requested_cents: 1800)
    settle_and_complete!(transaction.reload)
    assert AuditEvent.exists?(action: "pos.unlinked_return.applied", subject_id: unlinked.id)
    assert AuditEvent.exists?(action: "pos.transaction_completed", subject_id: sale_line.pos_transaction_id)
    assert_equal 1, OutboxMessage.where(event_type: "inventory.sale_posted", aggregate_id: sale_line.id).count
    assert_equal 1, OutboxMessage.where(event_type: "inventory.return_posted", aggregate_id: unlinked.id).count
    event = AuditEvent.find_by!(action: "pos.unlinked_return.applied", subject_id: unlinked.id)
    dumped = [ event.after_values, event.before_values, event.metadata ].compact.to_json
    refute_match(/password|correct-horse/i, dumped)
  end

  private

  def cancel_working!(transaction)
    Pos::CancelTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
  end

  def start_transaction
    Pos::StartTransaction.call(session: open_session, actor: @actor)
  end

  def open_session
    session = @context[:session]
    return session if session.reload.open?

    @context = pos_open_context(
      store: @store,
      actor: @actor,
      register: @context[:register],
      opening_float_cents: 50_000
    )
    @context[:session]
  end

  def priced_variants(*prices)
    untaxed = tax_class(code: "untaxed_mixed_#{SecureRandom.hex(3)}")
    StoreTaxes::EnsureRules.for_tax_class(untaxed)
    StoreTaxRule.find_by!(store_tax: StoreTax.find_by!(store: @store), tax_class: untaxed).update!(applies: false)
    prices.map.with_index do |cents, index|
      variant = pos_sellable_variant(actor: @actor, tax_class: untaxed, name: "Priced #{cents} #{index}")
      variant.update_columns(regular_price_cents: cents)
      open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 20, unit_cost_cents: 100)
      variant
    end
  end

  def add_sale!(transaction, source, quantity: 1)
    identifier = source.respond_to?(:sku) ? source.sku : source.unit_identifier
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: identifier,
      quantity: quantity
    )
  end

  def add_unlinked!(transaction, source, requested_cents:, quantity: 1)
    identifier = source.respond_to?(:sku) ? source.sku : source.unit_identifier
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: identifier,
      quantity: quantity,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: requested_cents
    )
  end

  def add_linked!(transaction, original_line, quantity: original_line.quantity)
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original_line,
      quantity: quantity,
      reason_code: "changed_mind"
    )
  end

  def cash_payment!(transaction, amount_cents)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: amount_cents
    )
  end

  def add_payment!(transaction, tender_type, amount_cents, reference)
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: tender_type,
      amount_cents: amount_cents,
      external_reference: reference
    )
  end

  def add_refund!(transaction, tender_type, amount_cents, reference = nil)
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: tender_type,
      amount_cents: amount_cents,
      external_reference: reference
    )
  end

  def settle_and_complete!(transaction)
    transaction.reload
    case Pos::Support.settlement_direction(transaction)
    when :payment
      cash_payment!(transaction, transaction.signed_net_cents)
    when :refund
      add_refund!(transaction, @cash, -transaction.signed_net_cents)
    end
    complete_current!(transaction.reload)
  end

  def complete_current!(transaction)
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    )
  end

  def complete_sale_and_unlinked!(sale:, unlinked:)
    transaction = start_transaction
    add_sale!(transaction, sale)
    add_unlinked!(transaction.reload, unlinked, requested_cents: unlinked.regular_price_cents)
    settle_and_complete!(transaction.reload)
  end

  def complete_sale_and_linked!(sale:, original_line:)
    transaction = start_transaction
    add_sale!(transaction, sale)
    add_linked!(transaction.reload, original_line)
    settle_and_complete!(transaction.reload)
  end

  def complete_priced_sale!(variant)
    transaction = start_transaction
    add_sale!(transaction, variant)
    settle_and_complete!(transaction.reload).transaction
  end

  def complete_quantity_sale!(quantity:)
    transaction = start_transaction
    add_sale!(transaction, @variant, quantity: quantity)
    settle_and_complete!(transaction.reload).transaction
  end

  def complete_unit_sale!(unit)
    transaction = start_transaction
    add_sale!(transaction, unit)
    settle_and_complete!(transaction.reload).transaction
  end

  def assert_directional_arithmetic!(txn)
    sale_lines = txn.pos_transaction_lines.select(&:sale?)
    return_lines = txn.pos_transaction_lines.select(&:return?)
    assert_equal sale_lines.sum(&:extended_selling_amount_cents), txn.subtotal_cents
    assert_equal sale_lines.sum(&:manual_discount_cents), txn.discount_cents
    assert_equal sale_lines.sum(&:line_tax_cents), txn.tax_cents
    assert_equal return_lines.sum(&:extended_selling_amount_cents), txn.return_subtotal_cents
    assert_equal return_lines.sum(&:manual_discount_cents), txn.return_discount_cents
    assert_equal return_lines.sum(&:line_tax_cents), txn.return_tax_cents
    assert_equal txn.return_subtotal_cents - txn.return_discount_cents + txn.return_tax_cents, txn.return_total_cents
    sale_total = txn.subtotal_cents - txn.discount_cents + txn.tax_cents
    assert_equal sale_total - txn.return_total_cents, txn.signed_net_cents
    assert_equal txn.signed_net_cents.abs, txn.total_cents
    unlinked = return_lines.select(&:unlinked_return?)
    if unlinked.any? { |line| line.selling_unit_price_cents != line.reference_unit_price_cents }
      assert_equal 0, unlinked.sum(&:manual_discount_cents)
    end
  end
end
