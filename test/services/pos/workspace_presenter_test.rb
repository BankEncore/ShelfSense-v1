# frozen_string_literal: true

require "test_helper"

class PosWorkspacePresenterTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book_wp", name: "Physical book")
    @state_tax = StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "5.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    Pos::TenderTypes.seed!
    @cash = TenderType.find_by!(code: "cash")
    @card = TenderType.find_by!(code: "card")
  end

  test "sale entry mode and command characterization" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    result = present(transaction, ui_mode: "sale_entry")

    assert_equal "SALE ENTRY", result.mode_label
    assert_equal "Scan or identifier", result.command_label
    assert_equal "text", result.command_inputmode
    assert result.close_session_available
    refute result.completion_recovery
  end

  test "quantity mode labels the selected line" do
    transaction = start_sale
    line = transaction.pos_transaction_lines.first
    result = present(transaction, ui_mode: "quantity", selected_line: line)

    assert_equal "QUANTITY", result.mode_label
    assert_match(/Current quantity #{line.quantity}/, result.command_label)
    assert_equal "numeric", result.command_inputmode
    refute result.close_session_available
  end

  test "completion failed keeps tenders visible and recovery flag" do
    transaction = start_sale
    tender_cash!(transaction, 2500)
    result = present(
      transaction.reload,
      ui_mode: "completion_failed",
      settlement_direction: :payment,
      remaining_payment_cents: 0,
      remaining_refund_cents: 0
    )

    assert result.completion_recovery
    assert result.locked
    assert_equal "CASH TENDER", result.mode_label
    assert_equal 1, result.tender_rows.size
    assert_equal %i[settled change], result.settlement_cues.map(&:kind)
    assert_equal "Settled", result.settlement_cues.first.label
    assert_equal "CHANGE", result.settlement_cues.second.label
  end

  test "sale only summary reconciles to signed net without Sales label" do
    transaction = start_sale
    line = transaction.pos_transaction_lines.includes(:pos_line_tax_components).first
    assert_operator line.pos_line_tax_components.size, :>, 0, "expected frozen tax components"
    result = present(transaction)

    assert_reconciles!(result, transaction)
    assert_equal "Merchandise", result.summary_rows.first.label
    refute(result.summary_rows.any? { |row| row.label == "Sales" })
    assert_equal "Net", result.summary_rows.last.label
    assert result.tax_groups.any?
    refute result.tax_fallback
  end

  test "return only signs returns and return tax" do
    original = complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
    )
    transaction.reload
    result = present(transaction, settlement_direction: :refund, remaining_refund_cents: -transaction.signed_net_cents)

    assert_reconciles!(result, transaction)
    returns_row = result.summary_rows.find { |row| row.key == :returns }
    assert returns_row
    assert returns_row.signed_cents.negative?
    assert(result.tax_groups.all? { |group| group.signed_cents.negative? })
    assert_equal "SALE ENTRY", result.mode_label
    assert_equal "Refund remaining", result.settlement_cues.first.label

    tender_result = present(transaction, ui_mode: "tender", settlement_direction: :refund,
                            remaining_refund_cents: -transaction.signed_net_cents)
    assert_equal "REFUND", tender_result.mode_label
  end

  test "mixed sale and return reconciles" do
    original = complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
    )
    transaction.reload
    result = present(transaction)

    assert_reconciles!(result, transaction)
    assert(result.summary_rows.any? { |row| row.key == :merchandise })
    assert(result.summary_rows.any? { |row| row.key == :returns })
  end

  test "gift card issuance contributes commercially not as tender" do
    GiftCards::Programs.seed!
    program = GiftCardProgram.find_by!(code: "generated")
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 2500,
      gift_card_program: program
    )
    transaction.reload
    result = present(transaction, action_capabilities: { gift_card_programs_available: true })

    assert_reconciles!(result, transaction)
    issuance_row = result.summary_rows.find { |row| row.key == :gift_cards_issued }
    assert_equal 2500, issuance_row.signed_cents
    assert_empty result.tender_rows
    assert result.issuance_remove_available
  end

  test "multiple tax groups group and order stably" do
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Local Tax",
      rate_percent: "1.000",
      calculation_order: 2,
      applies_by_tax_class_id: { @tax.id => true }
    )
    transaction = start_sale
    result = present(transaction)

    assert_reconciles!(result, transaction)
    assert_operator result.tax_groups.size, :>=, 2
    orders = result.tax_groups.map(&:calculation_order)
    assert_equal orders.sort, orders
    assert_equal result.tax_groups.sum(&:signed_cents), transaction.tax_cents - transaction.return_tax_cents
  end

  test "same tax group across sale lines aggregates" do
    transaction = start_sale
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    result = present(transaction)

    assert_reconciles!(result, transaction)
    assert_equal 1, result.tax_groups.size
    assert_equal transaction.tax_cents, result.tax_groups.first.signed_cents
  end

  test "return tax reduces its group" do
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Local Tax",
      rate_percent: "1.000",
      calculation_order: 2,
      applies_by_tax_class_id: { @tax.id => true }
    )
    original = complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
    )
    transaction.reload
    result = present(transaction)

    assert_reconciles!(result, transaction)
    assert_equal transaction.tax_cents - transaction.return_tax_cents, result.tax_groups.sum(&:signed_cents)
  end

  test "tax mismatch falls back to authoritative Net tax" do
    transaction = start_sale
    line = transaction.pos_transaction_lines.first
    line.pos_line_tax_components.destroy_all
    result = present(transaction.reload)

    assert result.tax_fallback
    assert_equal 1, result.tax_groups.size
    assert_equal "Net tax", result.tax_groups.first.name
    assert_equal transaction.tax_cents - transaction.return_tax_cents, result.tax_groups.first.signed_cents
    assert_reconciles!(result, transaction)
  end

  test "split payment keeps tenders outside the formula" do
    transaction = start_sale
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @card,
      amount_cents: 1000,
      external_reference: "AUTH-1"
    )
    transaction.reload
    remaining = Pos::Support.remaining_payment_cents(transaction)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: remaining
    )
    transaction.reload
    result = present(
      transaction,
      ui_mode: "tender",
      settlement_direction: :payment,
      remaining_payment_cents: 0
    )

    assert_reconciles!(result, transaction)
    formula = result.summary_rows.reject { |row| row.key == :net }.sum(&:signed_cents)
    assert_equal transaction.signed_net_cents, formula
    assert_equal 2, result.tender_rows.size
    refute(result.summary_rows.any? { |row| row.label.match?(/Cash|Card/i) })
  end

  test "cash overpayment keeps applied presented and change distinct" do
    transaction = start_sale
    tender_cash!(transaction, 5000)
    tender = transaction.reload.pos_tenders.sole
    result = present(
      transaction,
      ui_mode: "tender",
      settlement_direction: :payment,
      remaining_payment_cents: 0
    )

    row = result.tender_rows.sole
    assert_equal tender.amount_cents, row.amount_cents
    assert_equal tender.amount_presented_cents, row.presented_cents
    assert_equal tender.change_cents, row.change_cents
    assert_operator row.presented_cents, :>, row.amount_cents
    assert_equal %i[settled change], result.settlement_cues.map(&:kind)
    assert_equal "Settled", result.settlement_cues.first.label
    assert_equal "CHANGE", result.settlement_cues.second.label
    assert_equal tender.change_cents, result.settlement_cues.second.amount_cents
    assert_equal tender.change_cents, row.change_cents
  end

  test "exact non-cash payment shows Settled without fabricating amount due" do
    transaction = start_sale
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @card,
      amount_cents: transaction.signed_net_cents,
      external_reference: "AUTH-SETTLE"
    )
    transaction.reload
    result = present(
      transaction,
      ui_mode: "tender",
      settlement_direction: :payment,
      remaining_payment_cents: 0
    )

    assert_equal [ :settled ], result.settlement_cues.map(&:kind)
    assert_equal "Settled", result.settlement_cues.first.label
    refute(result.settlement_cues.any? { |cue| cue.kind == :balance_due || cue.kind == :change })
  end

  test "exact refund shows Settled" do
    original = complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
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
    result = present(
      transaction,
      ui_mode: "tender",
      settlement_direction: :refund,
      remaining_refund_cents: 0
    )

    assert_equal [ :settled ], result.settlement_cues.map(&:kind)
    assert_equal "Settled", result.settlement_cues.first.label
  end

  test "partial payment shows Balance due" do
    transaction = start_sale
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @card,
      amount_cents: 500,
      external_reference: "AUTH-PARTIAL"
    )
    transaction.reload
    remaining = Pos::Support.remaining_payment_cents(transaction)
    assert_operator remaining, :>, 0
    payment = present(
      transaction,
      ui_mode: "tender",
      settlement_direction: :payment,
      remaining_payment_cents: remaining
    )
    assert_equal [ :balance_due ], payment.settlement_cues.map(&:kind)
    assert_equal remaining, payment.settlement_cues.first.amount_cents
  end

  test "partial refund shows Refund remaining" do
    original = complete_cash_sale!
    refund_txn = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::ExecuteUnlinkedReturn.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
    )
    refund_txn.reload
    due = -refund_txn.signed_net_cents
    Pos::AddRefundTender.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      tender_type: @cash,
      amount_cents: [ due - 100, 1 ].max
    )
    refund_txn.reload
    remaining_refund = Pos::Support.remaining_refund_cents(refund_txn)
    assert_operator remaining_refund, :>, 0
    refund = present(
      refund_txn,
      ui_mode: "tender",
      settlement_direction: :refund,
      remaining_refund_cents: remaining_refund
    )
    assert_equal [ :refund_remaining ], refund.settlement_cues.map(&:kind)
    assert_equal remaining_refund, refund.settlement_cues.first.amount_cents
  end

  test "action capabilities come from the controller-supplied hash" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    denied = present(
      transaction,
      ui_mode: "sale_entry",
      action_capabilities: {
        close_session_available: false,
        issuance_remove_available: false
      }
    )
    assert_not denied.close_session_available
    assert_not denied.issuance_remove_available

    allowed = present(
      transaction,
      ui_mode: "tender",
      action_capabilities: {
        close_session_available: true,
        issuance_remove_available: true
      }
    )
    assert allowed.close_session_available
    assert allowed.issuance_remove_available
  end

  test "refund tender keeps positive applied amount with refund direction" do
    original = complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
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
    result = present(
      transaction,
      ui_mode: "tender",
      settlement_direction: :refund,
      remaining_refund_cents: 0
    )

    row = result.tender_rows.sole
    assert_equal "refund", row.direction
    assert_operator row.amount_cents, :>, 0
    assert_match(/refund/i, row.label)
  end

  test "even exchange is net zero with no fabricated amount due" do
    original = complete_cash_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: 1,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: original.pos_transaction_lines.first.selling_unit_price_cents
    )
    transaction.reload
    assert_equal 0, transaction.signed_net_cents
    result = present(transaction, settlement_direction: :none, remaining_payment_cents: 0, remaining_refund_cents: 0)

    assert_reconciles!(result, transaction)
    assert_equal "Even exchange", result.settlement_cues.first.label
    refute(result.settlement_cues.any? { |cue| cue.kind == :balance_due || cue.kind == :refund_remaining })
  end

  private

  def start_sale
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
  end

  def tender_cash!(transaction, presented_cents)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: presented_cents
    )
  end

  def complete_cash_sale!
    transaction = start_sale
    tender_cash!(transaction, 2500)
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    ).transaction
  end

  def present(
    transaction,
    ui_mode: "sale_entry",
    selected_line: nil,
    selected_tender_type: nil,
    settlement_direction: nil,
    remaining_payment_cents: nil,
    remaining_refund_cents: nil,
    command_value: nil,
    feedback: nil,
    action_capabilities: {}
  )
    lines = transaction.pos_transaction_lines.includes(:pos_line_tax_components, product_variant: :product).to_a
    tenders = transaction.pos_tenders.ordered.to_a
    issuances = transaction.pos_stored_value_issuances.ordered.to_a
    direction = settlement_direction || Pos::Support.settlement_direction(transaction)
    defaults = {
      close_session_available: ui_mode == "sale_entry" && lines.empty? && tenders.empty? && issuances.empty?,
      issuance_remove_available: ui_mode == "sale_entry",
      pickup_available: false,
      gift_card_programs_available: false
    }
    Pos::WorkspacePresenter.call(
      transaction: transaction,
      lines: lines,
      tenders: tenders,
      issuances: issuances,
      selected_line: selected_line || lines.first,
      selected_tender_type: selected_tender_type || (direction == :refund ? @cash : @cash),
      ui_mode: ui_mode,
      settlement_direction: direction,
      remaining_payment_cents: remaining_payment_cents || Pos::Support.remaining_payment_cents(transaction),
      remaining_refund_cents: remaining_refund_cents || Pos::Support.remaining_refund_cents(transaction),
      command_value: command_value,
      feedback: feedback,
      action_capabilities: defaults.merge(action_capabilities)
    )
  end

  def assert_reconciles!(result, transaction)
    total = result.summary_rows.reject { |row| row.key == :net }.sum(&:signed_cents)
    assert_equal transaction.signed_net_cents, total
    assert_equal transaction.signed_net_cents, result.summary_rows.last.signed_cents
  end
end
