# frozen_string_literal: true

require "test_helper"

class PosUnlinkedReturnCompletionTest < ActiveSupport::TestCase
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
    @context = pos_open_context(store: @store, actor: @actor)
    Pos::TenderTypes.seed!
    @cash = TenderType.find_by!(code: "cash")
  end

  test "freeze writes merchandise snapshot and keeps approved prices after a live variant change" do
    transaction = start_transaction
    line = add_unlinked!(transaction, requested_return_unit_price_cents: 1800)
    approved_reference = line.reference_unit_price_cents
    approved_selling = line.selling_unit_price_cents
    @variant.update_columns(regular_price_cents: 1)

    result = refund_and_complete!(transaction.reload)
    line.reload
    snapshot = line.merchandise_snapshot

    assert result.transaction.completed?
    assert_equal approved_reference, line.reference_unit_price_cents
    assert_equal approved_selling, line.selling_unit_price_cents
    assert_equal @variant.sku, snapshot["sku"]
    assert_equal @variant.product.name, snapshot["description"]
    assert_equal @tax.code, snapshot["tax_class_code"]
    refute snapshot.key?("unit_identifier")
    envelope = result.operation.envelope
    Pos::CompletedTransactionFacts.new(envelope).verify!
    adjustment = envelope.dig("lines", 0, "return_price_adjustment")
    assert_equal 1999, adjustment["reference_unit_price_cents"]
    assert_equal 1800, adjustment["resulting_unit_price_cents"]
    assert_equal(-199, adjustment["unit_variance_cents"])
    assert_equal(-199, adjustment["line_variance_cents"])
    refute envelope.dig("lines", 0).key?("override")
    refute envelope.dig("lines", 0).key?("discount")
    assert_equal 1, envelope.fetch("controlled_actions").count
    assert_equal "unlinked_return", envelope.dig("controlled_actions", 0, "action")
  end

  test "changing store tax after approval affects unlinked completion tax" do
    transaction = start_transaction
    line = add_unlinked!(transaction, requested_return_unit_price_cents: 2000)
    assert_equal 100, line.line_tax_cents

    StoreTaxes::Update.call(
      store_tax: @store_tax,
      actor: @actor,
      expected_lock_version: @store_tax.lock_version,
      rate_percent: "10.000"
    )
    Pos::FreezeUnlinkedReturnLine.call(transaction: transaction.reload, line: line.reload)
    assert_equal 200, line.reload.line_tax_cents
  end

  test "linked freeze never calls current tax calculate" do
    original = complete_quantity_sale!(quantity: 1)
    original_tax = original.pos_transaction_lines.first.line_tax_cents
    StoreTaxes::Update.call(
      store_tax: @store_tax.reload,
      actor: @actor,
      expected_lock_version: @store_tax.lock_version,
      rate_percent: "10.000"
    )
    transaction = start_transaction
    return_line = Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    Pos::FreezeLinkedReturnLine.call(transaction: transaction.reload, line: return_line.reload)
    assert_equal original_tax, return_line.reload.line_tax_cents
  end

  test "used freeze snapshot includes unit identity and condition" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    complete_unit_sale!(unit)
    transaction = start_transaction
    line = add_unlinked!(transaction, identifier: unit.unit_identifier, requested_return_unit_price_cents: 1200)
    refund_and_complete!(transaction.reload)

    snapshot = line.reload.merchandise_snapshot
    assert_equal used_variant.sku, snapshot["sku"]
    assert_equal unit.unit_identifier, snapshot["unit_identifier"]
    assert_equal used_variant.merchandise_condition.code, snapshot["condition_code"]
    assert unit.reload.on_hand?
    assert_equal 500, unit.carrying_value_cents
  end

  test "integrity refuses an unlinked line without the unlinked_return fact" do
    transaction = start_transaction
    line = add_unlinked!(transaction)
    line.pos_controlled_actions.delete_all
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @cash,
      amount_cents: -transaction.signed_net_cents
    )
    error = assert_raises(Pos::Error) { complete_current!(transaction.reload) }
    assert_match(/unlinked_return fact/, error.message)
  end

  test "completion refuses an unlinked line whose return reason drifted from the approved fact" do
    transaction = start_transaction
    line = add_unlinked!(transaction, requested_return_unit_price_cents: 1999)
    line.update_columns(
      return_reason_code: "defective",
      return_reason_name_snapshot: "Defective"
    )
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @cash,
      amount_cents: -transaction.signed_net_cents
    )
    error = assert_raises(Pos::Error) { complete_current!(transaction.reload) }
    assert_match(/return reason/, error.message)
  end

  test "freeze refuses a manual discount on an unlinked return" do
    transaction = start_transaction
    line = add_unlinked!(transaction)
    line.update_columns(manual_discount_basis_points: 1000)
    error = assert_raises(Pos::Error) do
      Pos::FreezeUnlinkedReturnLine.call(transaction: transaction.reload, line: line.reload)
    end
    assert_match(/sale discount/, error.message)

    error = assert_raises(Pos::Error) { Pos::CompletedTransactionIntegrity.verify!(transaction.reload) }
    assert_match(/sale discount/, error.message)
  end

  test "envelope forbids override discount and extra actions on an unlinked return" do
    transaction = start_transaction
    add_unlinked!(transaction, requested_return_unit_price_cents: 1800)
    envelope = refund_and_complete!(transaction.reload).operation.envelope.deep_dup
    Pos::CompletedTransactionFacts.new(envelope).verify!

    with_discount = envelope.deep_dup
    with_discount["lines"].first["discount"] = {
      "source" => "manual",
      "method" => "percentage",
      "basis_points" => 1000,
      "discount_cents" => 180,
      "net_merchandise_amount_cents" => 1620
    }
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(with_discount).verify! }
    assert_match(/cannot include discount/, error.message)

    with_override = envelope.deep_dup
    with_override["lines"].first["override"] = {
      "reference_unit_price_cents" => 1999,
      "selling_unit_price_cents" => 1800,
      "unit_variance_cents" => -199,
      "line_variance_cents" => -199
    }
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(with_override).verify! }
    assert_match(/cannot include override/, error.message)

    extra_action = envelope.deep_dup
    extra_action["controlled_actions"] << extra_action["controlled_actions"].first.merge(
      "action" => "price_override"
    )
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(extra_action).verify! }
    assert_match(/other controlled actions/, error.message)
  end

  test "malformed return_price_adjustment arithmetic is rejected" do
    transaction = start_transaction
    add_unlinked!(transaction, requested_return_unit_price_cents: 1800)
    envelope = refund_and_complete!(transaction.reload).operation.envelope.deep_dup
    Pos::CompletedTransactionFacts.new(envelope).verify!

    envelope["lines"].first["return_price_adjustment"]["line_variance_cents"] = 0
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(envelope).verify! }
    assert_match(/return_price_adjustment is invalid/, error.message)
  end

  test "return_price_adjustment is omitted when unlinked selling equals reference" do
    transaction = start_transaction
    add_unlinked!(transaction, requested_return_unit_price_cents: 1999)
    envelope = refund_and_complete!(transaction.reload).operation.envelope
    Pos::CompletedTransactionFacts.new(envelope).verify!
    refute envelope.fetch("lines").first.key?("return_price_adjustment")
  end

  test "return_price_adjustment is forbidden on sale and linked return envelopes" do
    sale = complete_quantity_sale!(quantity: 1)
    sale_envelope = PosOperation.find_by!(pos_transaction_id: sale.id).envelope.deep_dup
    sale_envelope["lines"].first["return_price_adjustment"] = { "reference_unit_price_cents" => 1 }
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(sale_envelope).verify! }
    assert_match(/cannot include return_price_adjustment/, error.message)

    transaction = start_transaction
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: sale.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    linked_envelope = refund_and_complete!(transaction.reload).operation.envelope.deep_dup
    linked_envelope["lines"].first["return_price_adjustment"] = {
      "reference_unit_price_cents" => 1999,
      "resulting_unit_price_cents" => 1800,
      "unit_variance_cents" => -199,
      "line_variance_cents" => -199
    }
    error = assert_raises(Pos::Error) { Pos::CompletedTransactionFacts.new(linked_envelope).verify! }
    assert_match(/cannot include return_price_adjustment/, error.message)
  end

  test "sale 30 plus unlinked 20 nets plus 10" do
    thirty, twenty = mixed_priced_variants
    result = complete_mixed!(sale_variant: thirty, unlinked_variant: twenty)
    assert_equal 1000, result.transaction.signed_net_cents
  end

  test "sale 20 plus unlinked 30 nets minus 10" do
    thirty, twenty = mixed_priced_variants
    result = complete_mixed!(sale_variant: twenty, unlinked_variant: thirty)
    assert_equal(-1000, result.transaction.signed_net_cents)
  end

  test "sale 20 plus unlinked 20 nets zero" do
    _thirty, twenty = mixed_priced_variants
    result = complete_mixed!(sale_variant: twenty, unlinked_variant: twenty)
    assert_equal 0, result.transaction.signed_net_cents
    assert_equal 0, result.transaction.pos_tenders.count
  end

  private

  def start_transaction
    Pos::StartTransaction.call(session: open_session, actor: @actor)
  end

  def open_session
    session = @context[:session]
    return session if session.reload.open?

    @context = pos_open_context(store: @store, actor: @actor, register: @context[:register])
    @context[:session]
  end

  def add_unlinked!(transaction, identifier: @variant.sku, quantity: 1, requested_return_unit_price_cents: 1999)
    Pos::ExecuteUnlinkedReturn.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: identifier,
      quantity: quantity,
      reason_code: "changed_mind",
      requested_return_unit_price_cents: requested_return_unit_price_cents
    )
  end

  def refund_and_complete!(transaction)
    transaction.reload
    if transaction.signed_net_cents.negative?
      Pos::AddRefundTender.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @cash,
        amount_cents: -transaction.signed_net_cents
      )
      transaction.reload
    elsif transaction.signed_net_cents.positive?
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: transaction.total_cents
      )
      transaction.reload
    end
    complete_current!(transaction)
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

  def complete_quantity_sale!(quantity:)
    transaction = start_transaction
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku,
      quantity: quantity
    )
    refund_and_complete!(transaction.reload).transaction
  end

  def complete_unit_sale!(unit)
    transaction = start_transaction
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    refund_and_complete!(transaction.reload).transaction
  end

  def mixed_priced_variants
    untaxed = tax_class(code: "untaxed_mixed")
    StoreTaxes::EnsureRules.for_tax_class(untaxed)
    StoreTaxRule.find_by!(store_tax: @store_tax, tax_class: untaxed).update!(applies: false)
    thirty = pos_sellable_variant(actor: @actor, tax_class: untaxed, name: "Thirty Book")
    twenty = pos_sellable_variant(actor: @actor, tax_class: untaxed, name: "Twenty Book")
    thirty.update_columns(regular_price_cents: 3000)
    twenty.update_columns(regular_price_cents: 2000)
    open_quantity_stock(store: @store, variant: thirty, actor: @actor, quantity: 5, unit_cost_cents: 100)
    open_quantity_stock(store: @store, variant: twenty, actor: @actor, quantity: 5, unit_cost_cents: 100)
    [ thirty, twenty ]
  end

  def complete_mixed!(sale_variant:, unlinked_variant:)
    transaction = start_transaction
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: sale_variant.sku
    )
    add_unlinked!(
      transaction.reload,
      identifier: unlinked_variant.sku,
      requested_return_unit_price_cents: unlinked_variant.regular_price_cents
    )
    refund_and_complete!(transaction.reload)
  end
end
