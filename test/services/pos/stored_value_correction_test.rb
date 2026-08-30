# frozen_string_literal: true

require "test_helper"

class PosStoredValueCorrectionTest < ActiveSupport::TestCase
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    @tax = tax_class(code: "sv_correction", name: "Stored value correction")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 40)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    GiftCards::Programs.seed!
    Pos::TenderTypes.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @gift_card_type = TenderType.find_by!(code: "gift_card")
    @store_credit_type = TenderType.find_by!(code: "store_credit")
    @cash = TenderType.find_by!(code: "cash")
  end

  # --- Auto-cap add -------------------------------------------------------

  test "over-balance request applies the available balance and reports the cap" do
    card = funded_card(500)
    transaction = start_sale

    result = add_stored_value(transaction, amount_cents: 1500, card: card)

    assert result.capped
    assert_equal 1500, result.requested_cents
    assert_equal 500, result.available_cents
    assert_equal 500, result.applied_cents
    assert_equal transaction.signed_net_cents - 500, result.remaining_due_cents
    assert_equal 500, result.tender.amount_cents
    assert_equal 500, transaction.reload.pos_tenders.sole.amount_cents

    event = AuditEvent.where(action: "pos.working_stored_value_tender.added").sole
    assert_equal 1500, event.metadata["requested_cents"]
    assert_equal 500, event.metadata["available_cents"]
    assert_equal true, event.metadata["capped"]
    refute_includes event.metadata.to_s, card.number
  end

  test "request over remaining due is rejected before any tender is written" do
    card = funded_card(50_000)
    transaction = start_sale

    error = assert_raises(Pos::Error) do
      add_stored_value(transaction, amount_cents: transaction.signed_net_cents + 1, card: card)
    end
    assert_match(/greater than remaining due/, error.message)
    assert_empty transaction.reload.pos_tenders
  end

  test "zero available balance refuses instead of applying nothing" do
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    transaction = start_sale

    error = assert_raises(Pos::Error) do
      add_stored_value(transaction, amount_cents: 500, card: card)
    end
    assert_match(/no available balance/, error.message)
    assert_empty transaction.reload.pos_tenders
  end

  test "lost-response retry replays the capped result instead of refusing a duplicate account" do
    card = funded_card(500)
    transaction = start_sale
    operation_id = SecureRandom.uuid_v7
    attrs = stored_value_attrs(transaction, amount_cents: 1500, card: card, operation_id: operation_id)

    first = Pos::AddStoredValueTender.call(**attrs)
    replay = Pos::AddStoredValueTender.call(**attrs)

    assert_not first.replayed
    assert replay.replayed
    assert replay.capped
    assert_equal first.tender.id, replay.tender.id
    assert_equal 1500, replay.requested_cents
    assert_equal 500, replay.available_cents
    assert_equal 500, replay.applied_cents
    assert_equal 1, transaction.reload.pos_tenders.count
  end

  test "a second card on the same account is refused but a different card is accepted" do
    card = funded_card(300)
    other = funded_card(300)
    transaction = start_sale
    add_stored_value(transaction, amount_cents: 300, card: card)

    error = assert_raises(Pos::Error) do
      add_stored_value(transaction.reload, amount_cents: 100, card: card)
    end
    assert_match(/already on the transaction/, error.message)

    add_stored_value(transaction.reload, amount_cents: 300, card: other)
    assert_equal 2, transaction.reload.pos_tenders.count
  end

  # --- Replace ------------------------------------------------------------

  test "replace keeps the same stored-value account and caps against the balance" do
    card = funded_card(800)
    transaction = start_sale
    original = add_stored_value(transaction, amount_cents: 200, card: card).tender

    result = Pos::ReplaceTender.call(
      transaction: transaction.reload,
      tender: original,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      amount_cents: 600
    )

    replacement = result.tender.reload
    assert_not_equal original.id, replacement.id
    assert_not result.capped
    assert_equal 600, replacement.amount_cents
    assert_equal card.stored_value_account_id, replacement.stored_value_tender_detail.stored_value_account_id
    assert_equal 1, transaction.reload.pos_tenders.count
    assert_equal 0, StoredValueOperation.where(operation_type: "redeem").count
  end

  test "replace over the balance caps and a failed replace leaves the original untouched" do
    card = funded_card(400)
    transaction = start_sale
    original = add_stored_value(transaction, amount_cents: 200, card: card).tender

    capped = Pos::ReplaceTender.call(
      transaction: transaction.reload,
      tender: original,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      amount_cents: 900
    )
    assert capped.capped
    assert_equal 400, capped.tender.reload.amount_cents

    surviving = capped.tender
    error = assert_raises(Pos::Error) do
      Pos::ReplaceTender.call(
        transaction: transaction.reload,
        tender: surviving,
        actor: @actor,
        operation_id: SecureRandom.uuid_v7,
        expected_lock_version: transaction.lock_version,
        amount_cents: transaction.reload.signed_net_cents + 1
      )
    end
    assert_match(/greater than remaining due/, error.message)
    assert_equal 400, surviving.reload.amount_cents
    assert_equal 1, transaction.reload.pos_tenders.count
  end

  # --- Issuance with tenders ----------------------------------------------

  test "adding an issuance while tenders are applied requires confirmation" do
    transaction = start_sale
    tender_cash!(transaction, transaction.signed_net_cents)

    error = assert_raises(Pos::Error) do
      add_issuance(transaction.reload, amount_cents: 2500)
    end
    assert_match(/must be cleared/, error.message)
    assert_equal 1, transaction.reload.pos_tenders.count
    assert_empty transaction.pos_stored_value_issuances
  end

  test "confirmed issuance add clears tenders, mutates, and replays" do
    transaction = start_sale
    tender_cash!(transaction, transaction.signed_net_cents)
    transaction.reload
    attrs = issuance_attrs(transaction, amount_cents: 2500, operation_id: SecureRandom.uuid_v7)
                .merge(confirm_clear_tenders: true)

    result = Pos::AddStoredValueIssuance.call(**attrs)
    assert_equal 1, result.cleared_tender_ids.size
    assert_empty transaction.reload.pos_tenders
    assert_equal 2500, transaction.pos_stored_value_issuances.sole.amount_cents

    replay = Pos::AddStoredValueIssuance.call(**attrs)
    assert replay.replayed
    assert_equal 1, transaction.reload.pos_stored_value_issuances.count
  end

  test "an invalid confirmed issuance changes nothing including the applied tenders" do
    @program.update!(minimum_activation_cents: 5000)
    transaction = start_sale
    tender_cash!(transaction, transaction.signed_net_cents)
    transaction.reload

    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueIssuance.call(
        **issuance_attrs(transaction, amount_cents: 100, operation_id: SecureRandom.uuid_v7)
          .merge(confirm_clear_tenders: true)
      )
    end
    assert_match(/below the program minimum/, error.message)
    assert_equal 1, transaction.reload.pos_tenders.count
    assert_empty transaction.pos_stored_value_issuances
  end

  test "removing an issuance while tenders are applied requires confirmation" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    issuance = add_issuance(transaction, amount_cents: 2500).issuance
    tender_cash!(transaction.reload, transaction.signed_net_cents)
    transaction.reload

    error = assert_raises(Pos::Error) do
      Pos::RemoveStoredValueIssuance.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        issuance: issuance,
        operation_id: SecureRandom.uuid_v7
      )
    end
    assert_match(/must be cleared/, error.message)
    assert_equal 1, transaction.reload.pos_tenders.count
    assert_equal 1, transaction.pos_stored_value_issuances.count

    attrs = {
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance: issuance,
      operation_id: SecureRandom.uuid_v7,
      confirm_clear_tenders: true
    }
    result = Pos::RemoveStoredValueIssuance.call(**attrs)
    assert_equal 1, result.cleared_tender_ids.size
    assert_empty transaction.reload.pos_tenders
    assert_empty transaction.pos_stored_value_issuances
    assert Pos::RemoveStoredValueIssuance.call(**attrs).replayed
  end

  test "issuance audit records masked identity only" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    manual = GiftCardProgram.find_by!(code: "manual")
    number = manual_card_number(manual)
    add_issuance(transaction, amount_cents: 2500, program: manual, card_number: number)

    event = AuditEvent.where(action: "pos.working_issuance.added").sole
    refute_includes event.after_values.to_s, number
    assert_includes event.after_values.fetch("masked_card_snapshot"), number.last(4)
  end

  # --- Completion recovery -------------------------------------------------

  test "balance reduced below the applied amount fails completion and keeps the tender" do
    card = funded_card(50_000)
    transaction = start_sale
    tender = add_stored_value(transaction, amount_cents: transaction.signed_net_cents, card: card).tender
    drain!(card, 49_000)

    error = assert_raises(Pos::StoredValueCompletionFailure) { complete!(transaction.reload) }
    assert_match(/balance is insufficient/, error.message)
    assert_equal tender.id, error.tender_id
    assert transaction.reload.working?
    assert_equal 1, transaction.pos_tenders.count
    assert_equal 0, StoredValueOperation.where(operation_type: "redeem").count
  end

  test "suspended and closed accounts fail completion and identify the tender" do
    card = funded_card(50_000)
    transaction = start_sale
    tender = add_stored_value(transaction, amount_cents: transaction.signed_net_cents, card: card).tender
    card.stored_value_account.update!(status: "suspended")

    error = assert_raises(Pos::StoredValueCompletionFailure) { complete!(transaction.reload) }
    assert_match(/not available/, error.message)
    assert_equal tender.id, error.tender_id
    assert_equal 1, transaction.reload.pos_tenders.count
  end

  test "customer no longer matching the account fails completion and identifies the tender" do
    customer = customer_with_store_credit(3000)
    transaction = start_sale
    Pos::AttachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: customer
    )
    transaction.reload
    tender = Pos::AddStoredValueTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @store_credit_type,
      amount_cents: transaction.signed_net_cents,
      operation_id: SecureRandom.uuid_v7
    ).tender
    transaction.reload.update_columns(customer_id: nil)

    error = assert_raises(Pos::StoredValueCompletionFailure) { complete!(transaction.reload) }
    assert_match(/customer is required/, error.message)
    assert_equal tender.id, error.tender_id
    assert_equal 1, transaction.reload.pos_tenders.count
  end

  test "refund capacity consumed elsewhere fails completion and identifies the tender" do
    card = funded_card(50_000)
    sale = mixed_gift_card_sale(card: card, gift_cents: 400, quantity: 2)
    first_line, second_line = sale.pos_transaction_lines.order(:line_number).to_a

    refund_txn = start_linked_return(sale, line: first_line)
    tender = add_gift_card_refund(refund_txn, amount_cents: 400, card: card)
    fill_cash_refund!(refund_txn.reload)

    competing_context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    competing = start_linked_return(sale, line: second_line, session: competing_context[:session])
    add_gift_card_refund(competing, amount_cents: 400, card: card)
    fill_cash_refund!(competing.reload)
    complete!(competing.reload, expected_signed_net_cents: competing.signed_net_cents)

    error = assert_raises(Pos::StoredValueCompletionFailure) do
      complete!(refund_txn.reload, expected_signed_net_cents: refund_txn.signed_net_cents)
    end
    assert_match(/gift-card-funded/, error.message)
    assert_equal tender.id, error.tender_id
    assert_equal 2, refund_txn.reload.pos_tenders.count
  end

  test "failure after an earlier nested post rolls everything back and retry posts once per tender" do
    first_card = funded_card(1000)
    transaction = start_sale
    second_card = funded_card(transaction.signed_net_cents - 1000)
    add_stored_value(transaction, amount_cents: 1000, card: first_card)
    second_amount = Pos::Support.remaining_payment_cents(transaction.reload)
    add_stored_value(transaction, amount_cents: second_amount, card: second_card)
    drain!(second_card, 500)

    assert_raises(Pos::StoredValueCompletionFailure) { complete!(transaction.reload) }
    assert_equal 0, StoredValueOperation.where(operation_type: "redeem").count
    assert_equal 2, transaction.reload.pos_tenders.count

    GiftCards::Fund.call(gift_card: second_card, amount_cents: 500, store: @store, performed_by: @actor)
    result = complete!(transaction.reload)

    assert result.transaction.completed?
    assert_equal 2, StoredValueOperation.where(operation_type: "redeem").count
    assert_equal 2, result.transaction.pos_tenders.filter_map { |tender|
      tender.stored_value_tender_detail&.stored_value_operation_id
    }.uniq.size
  end

  private

  def start_sale(quantity: 1)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    quantity.times do
      Pos::AddMerchandise.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        identifier: @variant.sku
      )
    end
    transaction.reload
  end

  def funded_card(cents)
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: cents, store: @store, performed_by: @actor)
    card
  end

  def drain!(card, cents)
    StoredValue::Post.call(
      operation_type: "adjust",
      store: @store,
      performed_by: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7,
      entries: [ { account: card.stored_value_account, amount_cents: -cents } ]
    )
  end

  def stored_value_attrs(transaction, amount_cents:, card:, operation_id: SecureRandom.uuid_v7)
    {
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @gift_card_type,
      amount_cents: amount_cents,
      operation_id: operation_id,
      card_number: card.number
    }
  end

  def add_stored_value(transaction, amount_cents:, card:)
    Pos::AddStoredValueTender.call(**stored_value_attrs(transaction, amount_cents: amount_cents, card: card))
  end

  def issuance_attrs(transaction, amount_cents:, operation_id:, program: nil, card_number: nil)
    {
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: amount_cents,
      operation_id: operation_id,
      gift_card_program: program || @program,
      card_number: card_number
    }
  end

  def add_issuance(transaction, amount_cents:, program: nil, card_number: nil)
    Pos::AddStoredValueIssuance.call(
      **issuance_attrs(
        transaction,
        amount_cents: amount_cents,
        operation_id: SecureRandom.uuid_v7,
        program: program,
        card_number: card_number
      )
    )
  end

  def manual_card_number(program)
    body_length = program.number_length - program.prefix.length - 1
    body = format("%0#{body_length}d", 12_345)
    base = "#{program.prefix}#{body}"
    "#{base}#{GiftCards::Luhn.check_digit(base)}"
  end

  def tender_cash!(transaction, cents)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: cents
    )
  end

  def customer_with_store_credit(cents)
    customer = Customer.create!(display_name: "SV Correction", email: "sv.correction#{SecureRandom.hex(3)}@example.com")
    account = StoredValue::EnsureCustomerAccount.call(customer: customer, account_type: "store_credit")
    StoredValue::AdjustmentReasons.seed!
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: cents,
      reason: StoredValueAdjustmentReason.find_by!(code: "goodwill"),
      store: @store,
      performed_by: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    customer
  end

  def mixed_gift_card_sale(card:, gift_cents:, quantity: 1)
    transaction = start_sale(quantity: quantity)
    add_stored_value(transaction, amount_cents: gift_cents, card: card)
    tender_cash!(transaction.reload, Pos::Support.remaining_payment_cents(transaction))
    complete!(transaction.reload).transaction
  end

  def start_linked_return(sale, line: nil, session: nil)
    refund_txn = Pos::StartTransaction.call(session: session || @context[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      original_line: line || sale.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    refund_txn.reload
  end

  def add_gift_card_refund(transaction, amount_cents:, card:)
    Pos::AddStoredValueRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @gift_card_type,
      amount_cents: amount_cents,
      destination_mode: "existing_account",
      operation_id: SecureRandom.uuid_v7,
      card_number: card.number
    ).tender
  end

  def fill_cash_refund!(transaction)
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @cash,
      amount_cents: Pos::Support.remaining_refund_cents(transaction)
    )
  end

  def complete!(transaction, expected_signed_net_cents: transaction.signed_net_cents)
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: expected_signed_net_cents
    )
  end
end
