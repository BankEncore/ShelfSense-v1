# frozen_string_literal: true

require "test_helper"

class PosLookupLinkedReturnTest < ActiveSupport::TestCase
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 40)
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "receipt barcode is exact transaction_reference and does not auto-return lines" do
    sale = complete_sale!
    working = Pos::StartTransaction.call(session: open_session, actor: @actor)
    result = Pos::LookupLinkedReturn.call(
      store: @store,
      query: sale.transaction_reference.downcase,
      current_transaction: working
    )

    assert_equal :lines, result.outcome
    assert_equal 1, result.lines.size
    assert_equal sale.pos_transaction_lines.first.id, result.lines.first.id
    assert_equal 0, working.reload.pos_transaction_lines.count
  end

  test "merchandise identifier lists recent returnable receipts without adding" do
    first = complete_sale!
    second = complete_sale!
    working = Pos::StartTransaction.call(session: open_session, actor: @actor)
    result = Pos::LookupLinkedReturn.call(
      store: @store,
      query: @variant.sku,
      current_transaction: working
    )

    assert_equal :receipts, result.outcome
    assert_equal [ first.transaction_reference, second.transaction_reference ].sort,
                 result.receipts.map(&:transaction_reference).sort
    later = [ first, second ].max_by(&:completed_at)
    assert_equal later.transaction_reference, result.receipts.first.transaction_reference
    assert_equal 0, working.reload.pos_transaction_lines.count
  end

  test "truncated merchandise lookup requires a receipt when more than 20 originals exist" do
    21.times { complete_sale! }
    result = Pos::LookupLinkedReturn.call(store: @store, query: @variant.sku)
    assert_equal :receipts, result.outcome
    assert_equal 20, result.receipts.size
    assert result.truncated
    assert_match(/receipt or use Transactions/i, result.message)
  end

  test "unit identifier lands on that receipt's returnable lines" do
    used, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    sale = complete_unit_sale!(unit)
    result = Pos::LookupLinkedReturn.call(store: @store, query: unit.unit_identifier)
    assert_equal :lines, result.outcome
    assert_equal sale.id, result.transaction_id
    assert_includes result.lines.map(&:id), sale.pos_transaction_lines.first.id
  end

  private

  def open_session
    session = @context[:session]
    return session if session.reload.open?

    @context = pos_open_context(store: @store, actor: @actor, register: @context[:register])
    @context[:session]
  end

  def complete_sale!
    transaction = Pos::StartTransaction.call(session: open_session, actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
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
