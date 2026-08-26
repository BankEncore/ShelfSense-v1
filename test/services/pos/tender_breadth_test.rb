# frozen_string_literal: true

require "test_helper"

class PosTenderBreadthTest < ActiveSupport::TestCase
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    @card = TenderType.find_by!(code: "card")
    @check = TenderType.find_by!(code: "check")
    @cash = TenderType.find_by!(code: "cash")
  end

  test "seeded identities are protected Cash Card and Check" do
    assert_equal %w[card cash check gift_card store_credit trade_credit], TenderType.order(:code).pluck(:code)
    assert TenderType.where(system_protected: true).where(code: %w[cash card check gift_card store_credit trade_credit]).count == 6
    assert_equal "omitted", @cash.external_reference_policy
    assert_equal "optional", @card.external_reference_policy
  end

  test "TenderCash remaining due excludes the existing Cash row and presented-only replace bumps lock_version" do
    transaction = start_sale
    first = Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    transaction.reload
    lock_after_first = transaction.lock_version
    assert_equal first.id, transaction.pos_tenders.cash.first.id
    assert_equal 1, first.tender_number

    second = Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 3000
    )
    transaction.reload
    assert_equal first.id, second.id
    assert_equal 1, second.tender_number
    assert_equal 3000, second.amount_presented_cents
    assert_equal transaction.total_cents, second.amount_cents
    assert_equal 3000 - transaction.total_cents, second.change_cents
    assert_operator transaction.lock_version, :>, lock_after_first
  end

  test "TenderCash replaces Cash in place and does not destroy Card" do
    transaction = start_sale
    add_card!(transaction, amount_cents: 1000)
    card_id = transaction.pos_tenders.find_by!(tender_type: "card").id

    cash = Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 1500
    )
    transaction.reload
    remaining_for_cash = transaction.total_cents - 1000
    assert_equal remaining_for_cash, cash.amount_cents
    assert_equal 1500 - remaining_for_cash, cash.change_cents
    assert_equal [ card_id ], transaction.pos_tenders.where(tender_type: "card").pluck(:id)
    assert_equal 2, transaction.pos_tenders.count
  end

  test "partial Cash is allowed only when other payments exist" do
    transaction = start_sale
    error = assert_raises(Pos::Error) do
      Pos::TenderCash.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        amount_presented_cents: 500
      )
    end
    assert_match(/less than amount due/, error.message)

    add_card!(transaction.reload, amount_cents: 1000)
    cash = Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 500
    )
    transaction.reload
    assert_equal 500, cash.amount_cents
    assert_equal 0, cash.change_cents
    assert_not Pos::Support.exact_settlement?(transaction)
  end

  test "AddTender rejects Cash identity over-remaining inactive type and blank required reference" do
    transaction = start_sale
    error = assert_raises(Pos::Error) do
      Pos::AddTender.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @cash,
        amount_cents: 1000
      )
    end
    assert_match(/use cash tender/, error.message)

    error = assert_raises(Pos::Error) do
      add_card!(transaction, amount_cents: transaction.total_cents + 1)
    end
    assert_match(/greater than remaining due/, error.message)

    @card.update!(active: false)
    error = assert_raises(Pos::Error) do
      Pos::AddTender.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @card,
        amount_cents: 1000
      )
    end
    assert_match(/not available/, error.message)
    @card.update!(active: true)

    other = TenderType.create!(
      code: "campus_charge",
      name: "Campus Charge",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )
    error = assert_raises(Pos::Error) do
      Pos::AddTender.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: other,
        amount_cents: 500
      )
    end
    assert_match(/reference is required/, error.message)

    Pos::AddTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: other,
      amount_cents: 500,
      external_reference: "PO-99"
    )
    transaction.reload
    tender = transaction.pos_tenders.find_by!(tender_type: "campus_charge")
    assert_equal "Campus Charge", tender.tender_name
    assert_equal "other", tender.behavioral_category
    assert_equal "PO-99", tender.external_reference
  end

  test "mixed Card and Cash completes with exact settlement and Card does not inflate expected Cash" do
    transaction = start_sale
    add_card!(transaction, amount_cents: 1000, reference: "AUTH-1")
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 1500
    )
    transaction.reload
    envelope = Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    ).operation.envelope

    tenders = envelope.fetch("tenders")
    assert_equal [ 1, 2 ], tenders.map { |tender| tender.fetch("tender_number") }
    card = tenders.find { |tender| tender.fetch("behavioral_category") == "card" }
    cash = tenders.find { |tender| tender.fetch("behavioral_category") == "cash" }
    assert_equal "External Card", card.fetch("tender_name")
    assert_equal "AUTH-1", card.fetch("external_reference")
    refute card.key?("amount_presented_cents")
    refute card.key?("change_cents")
    assert_equal 1000, card.fetch("amount_cents")
    assert_equal transaction.total_cents - 1000, cash.fetch("amount_cents")
    assert_equal 1500, cash.fetch("amount_presented_cents")

    totals = Pos::SessionTotals.for(@context[:session].reload)
    assert_equal 1000, totals.card_tender_cents
    assert_equal cash.fetch("amount_cents"), totals.cash_tender_cents
    assert_equal 10_000 + cash.fetch("amount_cents"), totals.expected_cash_cents
  end

  test "later admin rename does not rewrite a stored tender_name snapshot" do
    transaction = start_sale
    add_card!(transaction, amount_cents: 1000)
    @card.update!(name: "Bank Card")
    transaction.reload
    assert_equal "External Card", transaction.pos_tenders.find_by!(tender_type: "card").tender_name

    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 1500
    )
    transaction.reload
    envelope = Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    ).operation.envelope
    card = envelope.fetch("tenders").find { |tender| tender.fetch("tender_type") == "card" }
    assert_equal "External Card", card.fetch("tender_name")
  end

  test "remove renumbers densely and abandon clears all tenders" do
    transaction = start_sale
    add_card!(transaction, amount_cents: 500)
    add_check!(transaction, amount_cents: 400)
    first = transaction.pos_tenders.find_by!(tender_number: 1)
    Pos::RemoveWorkingTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender: first
    )
    transaction.reload
    remaining = transaction.pos_tenders.ordered.to_a
    assert_equal [ 1 ], remaining.map(&:tender_number)
    assert_equal "check", remaining.first.tender_type

    Pos::AbandonTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )
    assert_equal 0, transaction.reload.pos_tenders.count
  end

  test "Check-only completion snapshots Check and does not change expected Cash" do
    transaction = start_sale
    add_check!(transaction, amount_cents: transaction.total_cents)
    envelope = Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    ).operation.envelope

    tenders = envelope.fetch("tenders")
    assert_equal 1, tenders.size
    check = tenders.first
    assert_equal "check", check.fetch("behavioral_category")
    assert_equal "check", check.fetch("tender_type")
    assert_equal "Check", check.fetch("tender_name")
    assert_equal transaction.total_cents, check.fetch("amount_cents")
    refute check.key?("amount_presented_cents")
    refute check.key?("change_cents")
    assert_equal "Check", transaction.reload.pos_tenders.ordered.first.tender_name

    totals = Pos::SessionTotals.for(@context[:session].reload)
    assert_equal transaction.total_cents, totals.check_tender_cents
    assert_equal 0, totals.cash_tender_cents
    assert_equal 10_000, totals.expected_cash_cents
  end

  test "Other-only completion snapshots required reference and does not change expected Cash" do
    other = TenderType.create!(
      code: "campus_charge",
      name: "Campus Charge",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )
    transaction = start_sale
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: other,
      amount_cents: transaction.total_cents,
      external_reference: "PO-42"
    )
    envelope = Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    ).operation.envelope

    tenders = envelope.fetch("tenders")
    assert_equal 1, tenders.size
    other_tender = tenders.first
    assert_equal "other", other_tender.fetch("behavioral_category")
    assert_equal "campus_charge", other_tender.fetch("tender_type")
    assert_equal "Campus Charge", other_tender.fetch("tender_name")
    assert_equal "PO-42", other_tender.fetch("external_reference")
    assert_equal transaction.total_cents, other_tender.fetch("amount_cents")
    persisted = transaction.reload.pos_tenders.ordered.first
    assert_equal "campus_charge", persisted.tender_type
    assert_equal "Campus Charge", persisted.tender_name
    assert_equal "other", persisted.behavioral_category
    assert_equal "PO-42", persisted.external_reference

    totals = Pos::SessionTotals.for(@context[:session].reload)
    assert_equal transaction.total_cents, totals.other_tender_cents
    assert_equal 0, totals.cash_tender_cents
    assert_equal 10_000, totals.expected_cash_cents
  end

  test "FindCompletionOperation restores a token for exact mixed settlement without presented in the command" do
    transaction = start_sale
    add_card!(transaction, amount_cents: transaction.total_cents)
    assert Pos::Support.exact_settlement?(transaction.reload)
    payload = Pos::CompleteTransaction.command_payload(
      transaction: transaction,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    refute payload.key?("amount_presented_cents")
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

  test "new finalize writes category totals and already-finalized periods keep null category snapshots" do
    transaction = start_sale
    add_card!(transaction, amount_cents: transaction.total_cents)
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    pos_close_session!(
      session: @context[:session].reload,
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 10_000
    )
    period = Pos::FinalizeReportingPeriod.call(
      period: @context[:period].reload,
      actor: @actor,
      expected_lock_version: @context[:period].lock_version
    )
    assert_equal 0, period.finalized_cash_payment_cents
    assert_equal transaction.total_cents, period.finalized_card_payment_cents
    assert_equal 0, period.finalized_check_payment_cents
    assert_equal 0, period.finalized_other_payment_cents
    assert_equal 10_000, @context[:session].reload.closing_expected_cash_cents

    historical = PosReportingPeriod.create!(
      store: @store,
      register: Register.create!(store: @store, register_number: 99, name: "Historical"),
      status: "finalized",
      opened_at: Time.current,
      closed_at: Time.current,
      business_date: Date.new(2026, 8, 16),
      finalized_by_user_id: @actor.id,
      finalized_transaction_count: 0,
      finalized_subtotal_cents: 0,
      finalized_tax_cents: 0,
      finalized_total_cents: 0,
      finalized_cash_payment_cents: 0,
      finalized_session_count: 0,
      finalized_opening_float_cents_sum: 0,
      finalized_closing_expected_cash_cents_sum: 0,
      finalized_closing_count_cents_sum: 0,
      finalized_closing_variance_cents_sum: 0
    )
    assert_nil historical.finalized_card_payment_cents
    assert_nil Pos::PeriodTotals.for(historical).card_payment_cents
    assert_raises(ActiveRecord::ReadOnlyRecord) { historical.update!(finalized_card_payment_cents: 0) }
  end

  test "admin-created identities cannot use a protected category" do
    type = TenderType.new(
      code: "second_cash",
      name: "Second Cash",
      behavioral_category: "cash",
      external_reference_policy: "omitted"
    )
    assert_not type.valid?
    assert_includes type.errors[:behavioral_category], "must be other for admin-created identities"
    assert_not @cash.destroy
    assert TenderType.exists?(code: "cash")
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

  def add_card!(transaction, amount_cents:, reference: nil)
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @card,
      amount_cents: amount_cents,
      external_reference: reference
    )
    transaction.reload
  end

  def add_check!(transaction, amount_cents:)
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @check,
      amount_cents: amount_cents
    )
    transaction.reload
  end
end
