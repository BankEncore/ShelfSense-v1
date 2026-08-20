# frozen_string_literal: true

require "test_helper"

class PosPostVoidTransactionTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @store_tax = StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    Pos::TenderTypes.seed!
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
    @check = TenderType.find_by!(code: "check")
  end

  test "cash standard post-void mirrors lines tenders inventory and envelope" do
    source = complete_quantity_sale!(quantity: 1)
    source_line = source.pos_transaction_lines.first
    source_tender = source.pos_tenders.first
    source_envelope = source_operation(source).envelope.deep_dup
    source_hash = source_operation(source).envelope_hash
    on_hand_after_sale = InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
    source_valuation = InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: source_line.id,
      effect_sequence: 0
    )

    result = post_void!(source)
    reversal = result.transaction
    reversal_line = reversal.pos_transaction_lines.first
    envelope = result.operation.envelope

    assert reversal.completed?
    assert_equal source.id, reversal.post_void_of_transaction_id
    assert_equal "return", reversal_line.direction
    assert_equal source_line.id, reversal_line.post_void_source_line_id
    assert_nil reversal_line.original_transaction_line_id
    assert_nil reversal_line.return_reason_code
    assert_equal source_line.line_total_cents, reversal_line.line_total_cents
    assert_equal(-source.signed_net_cents, reversal.signed_net_cents)
    assert_equal source.currency_code, reversal.currency_code
    refute_equal source.transaction_reference, reversal.transaction_reference
    assert_equal source.reporting_period.business_date, reversal.business_date

    refund = reversal.pos_tenders.first
    assert_equal "refund", refund.direction
    assert_equal "cash", refund.behavioral_category
    assert_equal source_tender.amount_cents, refund.amount_cents
    assert_equal source_tender.id, refund.post_void_source_tender_id
    assert_nil refund.amount_presented_cents
    assert_nil refund.external_reference

    assert_equal source.id.to_s, envelope.dig("corrections", "post_void_of_transaction_id")
    assert_equal source.id.to_s, envelope.dig("corrections", "original_transaction_id")
    refute envelope.dig("corrections", "return_of_transaction_id")
    assert_equal reversal_line.id.to_s, envelope.dig("lines", 0, "line_id")
    assert_equal source_line.id.to_s, envelope.dig("lines", 0, "post_void_source_line_id")
    refute envelope.dig("lines", 0)&.key?("original_transaction_line_id")
    refute envelope.dig("lines", 0)&.key?("return_reason")
    assert_equal source_tender.id.to_s, envelope.dig("tenders", 0, "post_void_source_tender_id")
    action = envelope.fetch("controlled_actions").find { |row| row["action"] == "post_void" }
    assert action
    refute action.key?("subject")
    assert_equal "entered_in_error", action.dig("reason", "code")
    Pos::CompletedTransactionFacts.new(envelope).verify!

    ledger = InventoryLedgerEntry.find_by!(source_type: "PosTransactionLine", source_id: reversal_line.id)
    valuation = InventoryValuationEntry.find_by!(source_type: "PosTransactionLine", source_id: reversal_line.id)
    assert_equal "reversal", ledger.entry_type
    assert_equal source_valuation.id, valuation.reversal_of_id
    assert_equal(-source_valuation.value_delta_cents, valuation.value_delta_cents)
    assert_equal on_hand_after_sale + 1, InventoryBalance.find_by!(store: @store, product_variant: @variant).on_hand_quantity
    assert_equal 1, OutboxMessage.where(event_type: "inventory.post_void_posted").count
    assert AuditEvent.exists?(action: "inventory.post_void_posted", subject_id: reversal_line.id)
    assert AuditEvent.exists?(action: "pos.post_void.applied", subject_id: reversal.id)
    assert AuditEvent.exists?(action: "pos.transaction_completed", subject_id: reversal.id)

    source.reload
    assert_equal source_envelope, source_operation(source).envelope
    assert_equal source_hash, source_operation(source).envelope_hash
    refute source_operation(source).envelope.key?("corrections")
  end

  test "used sale post-void restores the original unit carrying value" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, unit_cost_cents: 500)
    source = complete_unit_sale!(unit)
    original_value = -InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: source.pos_transaction_lines.first.id,
      entry_type: "depletion"
    ).value_delta_cents
    assert unit.reload.removed?

    reversal = post_void!(source).transaction
    unit.reload
    assert unit.on_hand?
    assert_nil unit.removed_at
    assert_equal original_value, unit.carrying_value_cents
    valuation = InventoryValuationEntry.find_by!(
      source_type: "PosTransactionLine",
      source_id: reversal.pos_transaction_lines.first.id
    )
    assert_equal original_value, valuation.value_delta_cents
    assert_equal unit.id, valuation.inventory_unit_id
  end

  test "mixed tender card confirmation is required and original card reference is not copied" do
    source = complete_mixed_tender_sale!(card_cents: 1000, card_reference: "AUTH-OLD")
    card = source.pos_tenders.find_by!(behavioral_category: "card")
    cash = source.pos_tenders.find_by!(behavioral_category: "cash")

    error = assert_raises(Pos::Error) { post_void!(source) }
    assert_equal "Card reversal confirmation is required", error.message

    reversal = post_void!(
      source,
      card_reversals: [
        { "source_tender_id" => card.id, "confirmed" => true, "external_reference" => "REV-NEW" }
      ]
    ).transaction
    reversed_card = reversal.pos_tenders.find_by!(behavioral_category: "card")
    reversed_cash = reversal.pos_tenders.find_by!(behavioral_category: "cash")
    assert_equal "refund", reversed_card.direction
    assert_equal "REV-NEW", reversed_card.external_reference
    refute_equal "AUTH-OLD", reversed_card.external_reference
    assert_equal card.id, reversed_card.post_void_source_tender_id
    assert_equal "refund", reversed_cash.direction
    assert_equal cash.amount_cents, reversed_cash.amount_cents
    assert_nil reversed_cash.external_reference
  end

  test "check payment reverses as check refund without allows_refund" do
    assert_not @check.allows_refund?
    source = complete_check_sale!
    reversal = post_void!(source).transaction
    refund = reversal.pos_tenders.first
    assert_equal "check", refund.behavioral_category
    assert_equal "refund", refund.direction
    assert_equal source.pos_tenders.first.amount_cents, refund.amount_cents
  end

  test "post-void of a linked return restores original sale returnability" do
    sale = complete_quantity_sale!(quantity: 1)
    sale_line = sale.pos_transaction_lines.first
    returned = complete_linked_return!(original_line: sale_line, quantity: 1).transaction
    assert_equal 0, Pos::Returnability.remaining_quantity(sale_line)

    post_void!(returned)
    assert_equal 1, Pos::Returnability.remaining_quantity(sale_line.reload)
    summary = Pos::Returnability.summary_for([ sale_line ]).fetch(sale_line.id)
    assert_equal 0, summary.completed_returned_quantity
    assert_equal 1, summary.remaining_quantity
  end

  test "post-voided source sale remaining quantity is zero" do
    sale = complete_quantity_sale!(quantity: 2)
    sale_line = sale.pos_transaction_lines.first
    post_void!(sale)
    assert_equal 0, Pos::Returnability.remaining_quantity(sale_line.reload)
  end

  test "cannot post-void twice" do
    source = complete_quantity_sale!(quantity: 1)
    post_void!(source)
    error = assert_raises(Pos::Error) { post_void!(source.reload) }
    assert_equal "transaction has already been post-voided", error.message
  end

  test "cannot post-void a post-void" do
    source = complete_quantity_sale!(quantity: 1)
    reversal = post_void!(source).transaction
    error = assert_raises(Pos::Error) { post_void!(reversal) }
    assert_equal "cannot post-void a post-void", error.message
  end

  test "completed linked return blocks post-void of the source" do
    sale = complete_quantity_sale!(quantity: 1)
    complete_linked_return!(original_line: sale.pos_transaction_lines.first, quantity: 1)
    error = assert_raises(Pos::Error) { post_void!(sale) }
    assert_equal "a completed linked return exists for this transaction", error.message
  end

  test "working linked return on another session blocks post-void" do
    sale = complete_quantity_sale!(quantity: 1)
    other = pos_open_context(store: @store, actor: @actor, opening_float_cents: 0)
    working = Pos::StartTransaction.call(session: other[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      original_line: sale.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    error = assert_raises(Pos::Error) { post_void!(sale) }
    assert_equal "a working linked return exists for this transaction", error.message
  end

  test "linked return cannot be added against a post-voided source" do
    sale = complete_quantity_sale!(quantity: 1)
    original_line = sale.pos_transaction_lines.first
    post_void!(sale)
    working = Pos::StartTransaction.call(session: open_session, actor: @actor)
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
    assert_equal "original sale has been post-voided", error.message
  end

  test "lease replay returns the same reversal and mismatch is rejected" do
    source = complete_quantity_sale!(quantity: 1)
    operation_id = SecureRandom.uuid_v7
    reversal_id = SecureRandom.uuid_v7
    first = post_void!(source, operation_id: operation_id, reversal_transaction_id: reversal_id)
    second = post_void!(source, operation_id: operation_id, reversal_transaction_id: reversal_id)
    assert second.replayed
    assert_equal first.transaction.id, second.transaction.id
    assert_equal 1, PosTransaction.completed.where(post_void_of_transaction_id: source.id).count

    assert_raises(Pos::PayloadMismatch) do
      post_void!(
        source,
        operation_id: operation_id,
        reversal_transaction_id: reversal_id,
        reason_code: "duplicate_transaction"
      )
    end
  end

  test "post-void copies historical cents after the live tax rate changes" do
    source = complete_quantity_sale!(quantity: 1)
    source_line = source.pos_transaction_lines.first
    StoreTaxes::Update.call(
      store_tax: @store_tax.reload,
      actor: @actor,
      expected_lock_version: @store_tax.lock_version,
      rate_percent: "10.000"
    )
    reversal_line = post_void!(source).transaction.pos_transaction_lines.first
    assert_equal source_line.line_tax_cents, reversal_line.line_tax_cents
    assert_equal source_line.line_total_cents, reversal_line.line_total_cents
    refute_equal 2 * source_line.line_tax_cents, reversal_line.line_tax_cents
  end

  test "quantity inventory conflict refuses post-void of a later-sold return" do
    thin = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Thin Stock")
    open_quantity_stock(store: @store, variant: thin, actor: @actor, quantity: 1, unit_cost_cents: 100)
    sale = complete_quantity_sale!(quantity: 1, variant: thin)
    returned = complete_linked_return!(original_line: sale.pos_transaction_lines.first, quantity: 1).transaction
    complete_quantity_sale!(quantity: 1, variant: thin)

    error = assert_raises(Pos::Error) { post_void!(returned) }
    assert_equal Pos::PostVoidIntegrity::CONFLICT, error.message
  end

  test "used inventory conflict refuses post-void of a later-sold return" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, unit_cost_cents: 500)
    sale = complete_unit_sale!(unit)
    returned = complete_linked_return!(original_line: sale.pos_transaction_lines.first, quantity: 1).transaction
    complete_unit_sale!(unit.reload)

    error = assert_raises(Pos::Error) { post_void!(returned) }
    assert_equal Pos::PostVoidIntegrity::CONFLICT, error.message
  end

  test "session and z sales and returns exclude post-voids" do
    source = complete_quantity_sale!(quantity: 1)
    sale_subtotal = source.subtotal_cents
    sale_total = source.sale_total_cents
    reversal = post_void!(source).transaction
    totals = Pos::SessionTotals.for(open_session.reload)
    assert_equal 2, totals.completed_transaction_count
    assert_equal sale_subtotal, totals.subtotal_cents
    assert_equal 0, totals.return_total_cents
    assert_equal 1, totals.post_void_transaction_count
    assert_equal(-sale_subtotal, totals.post_void_merchandise_cents)
    assert_equal reversal.signed_net_cents, totals.post_void_net_cents
    assert_equal source.signed_net_cents + reversal.signed_net_cents, totals.net_cents
    assert totals.cash_refund_cents.positive?

    Pos::CloseSession.call(
      session: open_session,
      actor: @actor,
      expected_lock_version: open_session.lock_version,
      closing_count_cents: 0
    )
    period = Pos::FinalizeReportingPeriod.call(
      period: @context[:period].reload,
      actor: @actor,
      expected_lock_version: @context[:period].lock_version
    )
    z = Pos::PeriodTotals.for(period)
    assert_equal sale_subtotal, period.finalized_subtotal_cents
    assert_equal sale_total, period.finalized_total_cents
    assert_equal 0, period.finalized_return_total_cents
    assert_equal 1, period.finalized_post_void_transaction_count
    assert_equal(-sale_subtotal, period.finalized_post_void_merchandise_cents)
    assert_equal reversal.signed_net_cents, period.finalized_post_void_net_cents
    assert_equal 0, z.net_cents
    assert period.finalized_cash_refund_cents.positive?
  end

  test "pre-6.6 finalized post-void columns stay null" do
    unused = Pos::OpenReportingPeriod.call(
      store: @store,
      register: Register.create!(store: @store, register_number: 88, name: "Legacy Z"),
      actor: @actor
    )
    Pos::FinalizeReportingPeriod.call(period: unused, actor: @actor, expected_lock_version: unused.lock_version)
    PosReportingPeriod.where(id: unused.id).update_all(
      finalized_post_void_transaction_count: nil,
      finalized_post_void_merchandise_cents: nil,
      finalized_post_void_net_cents: nil
    )
    unused.reload
    assert_nil unused.finalized_post_void_transaction_count
    assert_nil Pos::PeriodTotals.for(unused).post_void_transaction_count
  end

  test "empty working basket is cancelled so post-void can complete" do
    source = complete_quantity_sale!(quantity: 1)
    empty = Pos::ResumeOrStartTransaction.call(session: open_session, actor: @actor)
    assert empty.working?
    assert_equal 0, empty.pos_transaction_lines.count

    reversal = post_void!(source).transaction
    assert reversal.completed?
    assert empty.reload.cancelled?
    refute open_session.pos_transactions.working.where.not(id: reversal.id).exists?
  end

  test "working basket with merchandise refuses post-void" do
    source = complete_quantity_sale!(quantity: 1)
    working = Pos::StartTransaction.call(session: open_session, actor: @actor)
    Pos::AddMerchandise.call(
      transaction: working,
      actor: @actor,
      expected_lock_version: working.lock_version,
      identifier: @variant.sku
    )
    error = assert_raises(Pos::Error) { post_void!(source) }
    assert_equal "Complete or cancel the current transaction before post-void.", error.message
    assert working.reload.working?
  end

  test "associate requires manager approval and denied is audited" do
    source = complete_quantity_sale!(quantity: 1)
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "pv_clerk")
    register = Register.create!(store: @store, register_number: 9, name: "Clerk")
    session = Pos::OpenSession.call(
      store: @store,
      register: register,
      actor: clerk,
      reporting_period: Pos::OpenReportingPeriod.call(store: @store, register: register, actor: @actor),
      opening_float_cents: 0
    )
    error = assert_raises(Pos::Denied) do
      Pos::PostVoidTransaction.call(
        source: source,
        actor: clerk,
        session: session,
        operation_id: SecureRandom.uuid_v7,
        reversal_transaction_id: SecureRandom.uuid_v7,
        reason_code: "entered_in_error"
      )
    end
    assert_match(/approver credentials are required/, error.message)
    assert AuditEvent.exists?(action: "pos.post_void.denied", subject_id: source.id)
  end

  test "phase 5 cash sale envelope stays ordinary when unused" do
    source = complete_quantity_sale!(quantity: 1)
    envelope = source_operation(source).envelope
    refute envelope.key?("corrections")
    refute envelope.dig("lines", 0)&.key?("post_void_source_line_id")
    Pos::CompletedTransactionFacts.new(envelope).verify!
  end

  private

  def post_void!(source, operation_id: SecureRandom.uuid_v7, reversal_transaction_id: SecureRandom.uuid_v7, reason_code: "entered_in_error", card_reversals: [])
    Pos::PostVoidTransaction.call(
      source: source,
      actor: @actor,
      session: open_session,
      operation_id: operation_id,
      reversal_transaction_id: reversal_transaction_id,
      reason_code: reason_code,
      card_reversals: card_reversals
    )
  end

  def source_operation(source)
    Pos::PostVoidTransaction.source_operation(source)
  end

  def start_sale(quantity: 1, variant: @variant, session: open_session)
    transaction = Pos::StartTransaction.call(session: session, actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: variant.sku,
      quantity: quantity
    )
    transaction.reload
  end

  def complete_quantity_sale!(quantity:, variant: @variant, session: open_session)
    transaction = start_sale(quantity: quantity, variant: variant, session: session)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    complete_current!(transaction.reload).transaction
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

  def complete_mixed_tender_sale!(card_cents:, card_reference:)
    transaction = start_sale
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @card,
      amount_cents: card_cents,
      external_reference: card_reference
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents - card_cents
    )
    complete_current!(transaction.reload).transaction
  end

  def complete_check_sale!
    transaction = start_sale
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @check,
      amount_cents: transaction.total_cents
    )
    complete_current!(transaction.reload).transaction
  end

  def complete_linked_return!(original_line:, quantity:)
    transaction = Pos::StartTransaction.call(session: open_session, actor: @actor)
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
