# frozen_string_literal: true

require "test_helper"

class Pos::CustomerReceiptTest < ActiveSupport::TestCase
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @tax = tax_class(code: "physical_book", name: "Physical book")
    StoreTaxes::Create.call(
      store: @store,
      actor: @actor,
      name: "Illinois State",
      rate_percent: "6.000",
      calculation_order: 1,
      applies_by_tax_class_id: { @tax.id => true }
    )
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @context = pos_open_context(store: @store, actor: @actor)
    @store.update!(legal_name: "Example Books LLC", street_address_1: "1234 Any Street", city: "Any Town", region_code: "MI", postal_code: "99999")
  end

  test "print totals equal signed_net_cents and use four-digit completion year" do
    transaction = complete_sale!

    receipt = Pos::CustomerReceipt.build(transaction)
    assert receipt.printable?
    assert_equal transaction.signed_net_cents, receipt.net_merchandise_cents + receipt.total_tax_cents
    assert_equal transaction.signed_net_cents.abs, receipt.total_display_cents
    assert_equal "Example Books LLC", receipt.legal_name
    assert_equal "TOTAL DUE", receipt.total_label
    assert_equal "Items Sold:", receipt.item_counts_label
    assert_equal "1", receipt.item_counts_value
    refute_includes receipt.address_lines, @store.name
    refute_equal receipt.completed_at_label, transaction.business_date.iso8601
    assert_match(/\A\d{1,2} [A-Z][a-z]{2} \d{4} \d{1,2}:\d{2}(am|pm)\z/, receipt.completed_at_label)
    assert receipt.merchandise_lines.one?
    assert_equal @variant.sku, receipt.merchandise_lines.first.identifier_value
    assert_equal "SKU", receipt.merchandise_lines.first.identifier_label
  end

  test "fails closed when legal_name is blank" do
    transaction = complete_sale!
    @store.update_columns(legal_name: nil)

    receipt = Pos::CustomerReceipt.build(transaction.reload)
    refute receipt.printable?
    assert_equal Pos::CustomerReceipt::MISSING_LEGAL_NAME, receipt.error
  end

  test "open-price lines do not print override provenance" do
    transaction = complete_sale!
    receipt = Pos::CustomerReceipt.build(transaction)
    text = receipt.merchandise_lines.map { |line|
      [ line.kind_banner, line.description, line.discount_label ]
    }.flatten.compact.join(" ")

    refute_match(/override|open price|reference price/i, text)
  end

  test "used freeze snapshots include condition_name on meta line" do
    _variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    cash_and_complete!(transaction.reload)
    snapshot = transaction.reload.pos_transaction_lines.first.merchandise_snapshot

    assert_equal unit.product_variant.merchandise_condition.name, snapshot.fetch("condition_name")
    receipt = Pos::CustomerReceipt.build(transaction)
    assert_equal "Used #{snapshot.fetch("condition_name")}", receipt.merchandise_lines.first.condition
  end

  test "code 128 encodes the compact reference" do
    svg = Pos::Code128.svg("S001-R01-T0000001")
    assert_includes svg, "<svg"
    assert_includes svg, "<rect"
    assert_includes svg, "S001-R01-T0000001"
  end

  test "old used snapshot with only condition_code prints Used code" do
    _variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    cash_and_complete!(transaction.reload)
    line = transaction.reload.pos_transaction_lines.first
    snapshot = line.merchandise_snapshot.merge("condition_code" => "VG")
    snapshot.delete("condition_name")
    PosTransactionLine.where(id: line.id).update_all(merchandise_snapshot: snapshot)

    receipt = Pos::CustomerReceipt.build(transaction.reload)
    assert_equal "Used VG", receipt.merchandise_lines.first.condition
  end

  test "tax groups use persisted store tax names" do
    transaction = complete_sale!
    receipt = Pos::CustomerReceipt.build(transaction)

    assert_equal 1, receipt.tax_groups.size
    assert_equal "Illinois State", receipt.tax_groups.first.name
    assert_equal "A", receipt.tax_groups.first.letter
  end

  test "stored-value activation uses persisted balance_after_cents" do
    GiftCards::Programs.seed!
    program = GiftCardProgram.find_by!(code: "generated")
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 2500,
      gift_card_program: program,
      operation_id: SecureRandom.uuid_v7
    )
    cash_and_complete!(transaction.reload)
    issuance = transaction.pos_stored_value_issuances.sole
    card = issuance.gift_card
    entry_balance = issuance.stored_value_operation.stored_value_entries.sole.balance_after_cents

    GiftCards::Fund.call(gift_card: card, amount_cents: 500, store: @store, performed_by: @actor)

    receipt = Pos::CustomerReceipt.build(transaction.reload)
    note = receipt.issued_balance_notes.sole
    assert_equal "New Balance", note.label
    assert_equal card.masked_number, note.masked_card
    assert_equal entry_balance, note.balance_cents
    refute_equal card.balance_cents, note.balance_cents
    assert receipt.stored_value_issuances.one?
    assert receipt.stored_value_issuances.first.activation
  end

  private

  def complete_sale!
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    cash_and_complete!(transaction.reload)
  end

  def cash_and_complete!(transaction)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    ).transaction
  end
end
