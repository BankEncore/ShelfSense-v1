# frozen_string_literal: true

require "test_helper"

class PosWorkspaceInvariantsTest < ActiveSupport::TestCase
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
    @context = pos_open_context(store: @store, actor: @actor)
  end

  test "start transaction rejects a second working row" do
    first = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    error = assert_raises(Pos::Error) do
      Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    end
    assert_match(/working transaction already exists/, error.message)
    assert_equal 1, PosTransaction.working.where(pos_session: @context[:session]).count
    assert_equal first.id, PosTransaction.working.find_by!(pos_session: @context[:session]).id
  end

  test "resume or start creates then returns the same working transaction" do
    created = Pos::ResumeOrStartTransaction.call(session: @context[:session], actor: @actor)
    resumed = Pos::ResumeOrStartTransaction.call(session: @context[:session], actor: @actor)
    assert_equal created.id, resumed.id
    assert_equal 1, PosTransaction.working.where(pos_session: @context[:session]).count
  end

  test "resume or start is denied to a second cashier" do
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_resume")
    assert_raises(Pos::Denied) do
      Pos::ResumeOrStartTransaction.call(session: @context[:session], actor: other)
    end
    assert_equal 0, PosTransaction.where(pos_session: @context[:session]).count
  end

  test "add merchandise rescans a compatible sku onto the existing line" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    first = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    second = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    assert_equal first.id, second.id
    assert_equal 2, second.quantity
    assert_equal 1, transaction.pos_transaction_lines.count
    assert_equal 3998, transaction.subtotal_cents
    assert_equal 200, transaction.tax_cents
    assert_equal 4198, transaction.total_cents
  end

  test "add merchandise keeps an incompatible price context as a separate line" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    first = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    first.update_columns(selling_unit_price_cents: 1500, extended_selling_amount_cents: 1500)
    transaction.reload
    second = Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    assert_not_equal first.id, second.id
    assert_equal 2, transaction.pos_transaction_lines.count
    assert_equal 1, second.quantity
    assert_equal 1999, second.selling_unit_price_cents
  end

  test "basket mutation clears a working cash tender and refreshes lock_version" do
    transaction = working_sale_with_tender
    original_version = transaction.lock_version
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert_operator transaction.lock_version, :>, original_version
    assert transaction.working?
  end

  test "change quantity and remove working line clear a working cash tender" do
    transaction = working_sale_with_tender
    line = transaction.pos_transaction_lines.first
    Pos::ChangeQuantity.call(
      transaction: transaction,
      line: line,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      quantity: 2
    )
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert transaction.working?

    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::RemoveWorkingLine.call(
      transaction: transaction,
      line: line,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert_equal 0, transaction.pos_transaction_lines.count
    assert transaction.working?
  end

  test "abandon tender removes a cash tender and bumps lock_version" do
    transaction = working_sale_with_tender
    original_version = transaction.lock_version
    Pos::AbandonTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert_equal original_version + 1, transaction.lock_version
    assert transaction.working?
  end

  test "abandon tender is a successful no-op without a lock_version bump when there is no tender" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    original_version = transaction.lock_version
    Pos::AbandonTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    transaction.reload
    assert_equal original_version, transaction.lock_version
    assert transaction.working?
  end

  test "abandon tender rejects a second cashier stale version and completed transactions" do
    transaction = working_sale_with_tender
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_abandon")
    assert_raises(Pos::Denied) do
      Pos::AbandonTender.call(
        transaction: transaction,
        actor: other,
        expected_lock_version: transaction.lock_version
      )
    end
    assert_raises(Pos::StaleObject) do
      Pos::AbandonTender.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version - 1
      )
    end
    assert_equal 1, transaction.reload.pos_tenders.count

    complete_current_sale!(transaction)
    assert_raises(Pos::Error) do
      Pos::AbandonTender.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version
      )
    end
  end

  test "cancel discards working tenders keeps lines and does not change expected cash" do
    transaction = working_sale_with_tender
    line_id = transaction.pos_transaction_lines.first.id
    Pos::CancelTransaction.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    transaction.reload
    assert transaction.cancelled?
    assert_equal 0, transaction.pos_tenders.count
    assert_equal line_id, transaction.pos_transaction_lines.first.id
    assert_equal 0, Pos::SessionTotals.for(@context[:session]).expected_cash_cents
  end

  test "cancel of an empty working transaction remains allowed" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::CancelTransaction.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    assert transaction.reload.cancelled?
  end

  test "find completion operation restores the matching failed attempt and ignores a prior abandoned tender" do
    transaction = working_sale_with_tender
    first_id = SecureRandom.uuid_v7
    assert_raises(Pos::Error) do
      Pos::CompleteTransaction.call(
        transaction: transaction,
        actor: @actor,
        operation_id: first_id,
        expected_lock_version: transaction.lock_version,
        expected_total_cents: transaction.total_cents,
        amount_presented_cents: 2500
      )
    end
    assert_equal first_id, Pos::FindCompletionOperation.call(transaction: transaction.reload, actor: @actor).id

    Pos::AbandonTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    transaction.reload
    assert_nil Pos::FindCompletionOperation.call(transaction: transaction, actor: @actor)

    second_id = SecureRandom.uuid_v7
    assert_raises(Pos::Error) do
      Pos::CompleteTransaction.call(
        transaction: transaction,
        actor: @actor,
        operation_id: second_id,
        expected_lock_version: transaction.lock_version,
        expected_total_cents: transaction.total_cents,
        amount_presented_cents: 2500
      )
    end
    found = Pos::FindCompletionOperation.call(transaction: transaction.reload, actor: @actor)
    assert_equal second_id, found.id
    assert_equal "failed", found.status
  end

  test "find completion operation is denied to a second cashier and nil without a cash tender" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    assert_nil Pos::FindCompletionOperation.call(transaction: transaction, actor: @actor)

    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_finder")
    assert_raises(Pos::Denied) do
      Pos::FindCompletionOperation.call(transaction: transaction, actor: other)
    end
  end

  private

  def working_sale_with_tender
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
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
      amount_presented_cents: 2500
    )
    transaction.reload
  end

  def complete_current_sale!(transaction)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: transaction.pos_tenders.first.amount_presented_cents
    )
  end
end
