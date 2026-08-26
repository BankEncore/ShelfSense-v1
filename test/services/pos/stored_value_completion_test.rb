# frozen_string_literal: true

require "test_helper"

class PosStoredValueCompletionTest < ActiveSupport::TestCase
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 10, unit_cost_cents: 100)
    @context = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    GiftCards::Programs.seed!
    Pos::TenderTypes.seed!
    @program = GiftCardProgram.find_by!(code: "generated")
    @gift_card_type = TenderType.find_by!(code: "gift_card")
    @store_credit_type = TenderType.find_by!(code: "store_credit")
    @trade_credit_type = TenderType.find_by!(code: "trade_credit")
    @cash = TenderType.find_by!(code: "cash")
  end

  test "generated activation increases signed net, posts activate, and first print decrypts" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    assert_equal SystemSettings.current.base_currency_code, transaction.currency_code

    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 2500,
      gift_card_program: @program
    )
    transaction.reload
    assert_equal 2500, transaction.stored_value_issuance_cents
    assert_equal 2500, transaction.signed_net_cents
    assert_equal 0, transaction.sale_total_cents

    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    result = complete_current!(transaction.reload)
    issuance = result.transaction.pos_stored_value_issuances.sole
    card = issuance.gift_card

    assert result.transaction.completed?
    assert_equal "activate", issuance.stored_value_operation.operation_type
    assert_equal 2500, card.stored_value_account.balance_cents
    assert_equal 3, result.operation.envelope.fetch("schema_version")
    assert_equal 2500, result.operation.envelope.dig("transaction", "stored_value_issuance_cents")
    refute result.operation.envelope.to_s.include?(card.number)
    credentials = Pos::FirstPrint.call(result.transaction)
    assert_equal 1, credentials.size
    assert_equal card.number, credentials.first.number
    assert_equal [], Pos::FirstPrint.call(result.transaction)
    assert PosGiftCardCredentialDelivery.exists?(pos_transaction_id: result.transaction.id)
    Pos::CompletedTransactionFacts.new(result.operation.envelope).verify!
    receipt = Pos::CustomerReceipt.build(result.transaction)
    assert_equal result.transaction.signed_net_cents, receipt.signed_net_cents
    note = receipt.remaining_balance_notes.sole
    assert_equal card.masked_number, note.masked_card
    assert_equal 2500, note.balance_cents
  end

  test "first print does not decrypt after the originating session is closed" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 1200,
      gift_card_program: @program
    )
    Pos::TenderCash.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 1200
    )
    result = complete_current!(transaction.reload)
    card = result.transaction.pos_stored_value_issuances.sole.gift_card
    Pos::CloseSession.call(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 11_200
    )

    assert_equal [], Pos::FirstPrint.call(result.transaction)
    refute PosGiftCardCredentialDelivery.exists?(pos_transaction_id: result.transaction.id)
    recovered = GiftCards::PrintRecovery.call(
      gift_card: card,
      actor: @actor,
      store: @store,
      reason: "session closed before voucher print"
    )
    assert_equal card.number, recovered
  end

  test "gift-card redeem posts a negative redeem and rejects same-ticket issuance" do
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: 5000, store: @store, performed_by: @actor)

    transaction = start_sale
    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueIssuance.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        issuance_type: "activation",
        amount_cents: 1000,
        gift_card_program: @program
      )
      Pos::AddStoredValueTender.call(
        transaction: transaction.reload,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @gift_card_type,
        amount_cents: 1000,
        card_number: card.number
      )
    end
    assert_match(/cannot redeem stored value on a ticket with gift-card issuance/, error.message)
    Pos::CancelTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version
    )

    transaction = start_sale
    Pos::AddStoredValueTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @gift_card_type,
      amount_cents: transaction.signed_net_cents,
      card_number: card.number
    )
    result = complete_current!(transaction.reload)
    detail = result.transaction.pos_tenders.sole.stored_value_tender_detail
    assert_equal "redeem", detail.stored_value_operation.operation_type
    assert_equal 5000 - result.transaction.signed_net_cents, card.stored_value_account.reload.balance_cents
  end

  test "store-credit payment requires a customer and trade credit is not a generic refund destination" do
    customer = Customer.create!(display_name: "POS Customer", email: "pos.sv@example.com")
    account = StoredValue::EnsureCustomerAccount.call(customer: customer, account_type: "store_credit")
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: 3000,
      reason: StoredValueAdjustmentReason.find_by!(code: "goodwill"),
      store: @store,
      performed_by: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    transaction = start_sale
    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueTender.call(
        transaction: transaction,
        actor: @actor,
        expected_lock_version: transaction.lock_version,
        tender_type: @store_credit_type,
        amount_cents: 1000
      )
    end
    assert_match(/customer is required/, error.message)

    Pos::AttachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: customer
    )
    Pos::AddStoredValueTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @store_credit_type,
      amount_cents: transaction.signed_net_cents
    )
    result = complete_current!(transaction.reload)
    assert_equal "redeem", result.transaction.pos_tenders.sole.stored_value_tender_detail.stored_value_operation.operation_type

    refund_txn = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      original_line: result.transaction.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    refund_txn.reload
    Pos::AttachCustomer.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      customer: customer
    )
    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueRefundTender.call(
        transaction: refund_txn.reload,
        actor: @actor,
        expected_lock_version: refund_txn.lock_version,
        tender_type: @trade_credit_type,
        amount_cents: -refund_txn.signed_net_cents,
        destination_mode: "existing_account"
      )
    end
    assert_match(/original account|trade credit/, error.message)

    Pos::AddStoredValueRefundTender.call(
      transaction: refund_txn.reload,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      tender_type: @store_credit_type,
      amount_cents: -refund_txn.signed_net_cents,
      destination_mode: "customer_store_credit"
    )
    refund_result = complete_current!(refund_txn.reload, expected_signed_net_cents: refund_txn.signed_net_cents)
    assert_equal "refund", refund_result.transaction.pos_tenders.sole.stored_value_tender_detail.stored_value_operation.operation_type
  end

  test "trade-credit original tender refunds return to the same account" do
    customer = Customer.create!(display_name: "Trade Customer", email: "pos.trade@example.com")
    account = StoredValue::EnsureCustomerAccount.call(customer: customer, account_type: "trade_credit")
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: 3000,
      reason: StoredValueAdjustmentReason.find_by!(code: "goodwill"),
      store: @store,
      performed_by: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
    opening_balance = account.reload.balance_cents

    transaction = start_sale
    Pos::AttachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: customer
    )
    Pos::AddStoredValueTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @trade_credit_type,
      amount_cents: transaction.signed_net_cents
    )
    sale = complete_current!(transaction.reload).transaction
    assert_equal opening_balance - sale.signed_net_cents, account.reload.balance_cents

    refund_txn = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      original_line: sale.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    Pos::AttachCustomer.call(
      transaction: refund_txn.reload,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      customer: customer
    )
    Pos::AddStoredValueRefundTender.call(
      transaction: refund_txn.reload,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      tender_type: @trade_credit_type,
      amount_cents: -refund_txn.signed_net_cents,
      destination_mode: "existing_account"
    )
    refund = complete_current!(refund_txn.reload, expected_signed_net_cents: refund_txn.signed_net_cents).transaction
    assert_equal "refund", refund.pos_tenders.sole.stored_value_tender_detail.stored_value_operation.operation_type
    assert_equal account.id, refund.pos_tenders.sole.stored_value_tender_detail.stored_value_account_id
    assert_equal opening_balance, account.reload.balance_cents
  end

  test "gift-card shaped scans do not resolve as merchandise" do
    number = GiftCards::Number.generate(@program)
    result = Pos::ResolveMerchandiseForSale.call(store: @store, identifier: number)
    assert_equal :gift_card, result.outcome
    assert_nil result.gift_card
    assert_equal @program.id, result.gift_card_program.id
  end

  test "post-void reverses activation and blocks when downstream spend would overdraw" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 2500,
      gift_card_program: @program
    )
    Pos::TenderCash.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    source = complete_current!(transaction.reload).transaction
    card = source.pos_stored_value_issuances.sole.gift_card

    reversal = Pos::PostVoidTransaction.call(
      source: source,
      actor: @actor,
      session: @context[:session],
      operation_id: SecureRandom.uuid_v7,
      reversal_transaction_id: SecureRandom.uuid_v7,
      reason_code: "entered_in_error"
    ).transaction
    assert_equal(-source.signed_net_cents, reversal.signed_net_cents)
    assert_equal 0, card.stored_value_account.reload.balance_cents

    activation = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: activation,
      actor: @actor,
      expected_lock_version: activation.lock_version,
      issuance_type: "activation",
      amount_cents: 2500,
      gift_card_program: @program
    )
    Pos::TenderCash.call(
      transaction: activation.reload,
      actor: @actor,
      expected_lock_version: activation.lock_version,
      amount_presented_cents: 2500
    )
    loaded = complete_current!(activation.reload).transaction
    funded = loaded.pos_stored_value_issuances.sole.gift_card
    spend = start_sale
    Pos::AddStoredValueTender.call(
      transaction: spend,
      actor: @actor,
      expected_lock_version: spend.lock_version,
      tender_type: @gift_card_type,
      amount_cents: spend.signed_net_cents,
      card_number: funded.number
    )
    complete_current!(spend.reload)

    error = assert_raises(Pos::Error) do
      Pos::PostVoidTransaction.call(
        source: loaded,
        actor: @actor,
        session: @context[:session],
        operation_id: SecureRandom.uuid_v7,
        reversal_transaction_id: SecureRandom.uuid_v7,
        reason_code: "entered_in_error"
      )
    end
    assert_match(/downstream stored-value activity/, error.message)
  end

  test "complete-retry can still first-print until delivery is recorded" do
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "activation",
      amount_cents: 2500,
      gift_card_program: @program
    )
    Pos::TenderCash.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
    operation_id = SecureRandom.uuid_v7
    transaction.reload
    complete_attrs = {
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    }
    first = Pos::CompleteTransaction.call(**complete_attrs)
    replay = Pos::CompleteTransaction.call(**complete_attrs)
    card = first.transaction.pos_stored_value_issuances.sole.gift_card
    credentials = Pos::FirstPrint.call(replay.transaction)
    assert_equal card.number, credentials.sole.number
  end

  test "new refund gift card cannot exceed remaining gift-card-funded amount" do
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: 5000, store: @store, performed_by: @actor)
    sale = mixed_gift_card_and_cash_sale(card: card, gift_cents: 100)

    refund_txn = start_linked_return(sale)
    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueRefundTender.call(
        transaction: refund_txn,
        actor: @actor,
        expected_lock_version: refund_txn.lock_version,
        tender_type: @gift_card_type,
        amount_cents: -refund_txn.signed_net_cents,
        destination_mode: "new_gift_card",
        gift_card_program: @program
      )
    end
    assert_match(/gift-card-funded/, error.message)

    Pos::AddStoredValueRefundTender.call(
      transaction: refund_txn.reload,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      tender_type: @gift_card_type,
      amount_cents: 100,
      destination_mode: "new_gift_card",
      gift_card_program: @program
    )
    Pos::AddRefundTender.call(
      transaction: refund_txn.reload,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      tender_type: @cash,
      amount_cents: Pos::Support.remaining_refund_cents(refund_txn)
    )
    refund = complete_current!(refund_txn.reload, expected_signed_net_cents: refund_txn.signed_net_cents).transaction
    assert_equal 100, refund.pos_tenders.find { |tender| tender.tender_type == "gift_card" }.amount_cents
  end

  test "trade-credit refund cannot exceed the original trade-credit-funded portion" do
    customer = Customer.create!(display_name: "Mixed Trade", email: "mixed.trade@example.com")
    account = StoredValue::EnsureCustomerAccount.call(customer: customer, account_type: "trade_credit")
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: 3000,
      reason: StoredValueAdjustmentReason.find_by!(code: "goodwill"),
      store: @store,
      performed_by: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    transaction = start_sale
    Pos::AttachCustomer.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      customer: customer
    )
    Pos::AddStoredValueTender.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @trade_credit_type,
      amount_cents: 100
    )
    Pos::TenderCash.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: Pos::Support.remaining_payment_cents(transaction)
    )
    sale = complete_current!(transaction.reload).transaction

    refund_txn = start_linked_return(sale)
    Pos::AttachCustomer.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      customer: customer
    )
    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueRefundTender.call(
        transaction: refund_txn.reload,
        actor: @actor,
        expected_lock_version: refund_txn.lock_version,
        tender_type: @trade_credit_type,
        amount_cents: -refund_txn.signed_net_cents,
        destination_mode: "existing_account"
      )
    end
    assert_match(/trade-credit-funded/, error.message)
  end

  test "completion rechecks gift-card maximum after two working reloads" do
    @program.update!(maximum_balance_cents: 1000)
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: 400, store: @store, performed_by: @actor)

    first = build_reload_ticket(card, 400, session: @context[:session])
    other = pos_open_context(store: @store, actor: @actor, opening_float_cents: 10_000)
    second = build_reload_ticket(card, 400, session: other[:session])

    complete_current!(first.reload)
    error = assert_raises(Pos::Error) { complete_current!(second.reload) }
    assert_match(/maximum balance/, error.message)
    assert_equal 800, card.stored_value_account.reload.balance_cents
  end

  test "new refund gift card cannot exceed the program maximum balance" do
    card = GiftCards::ProvisionInstrument.call(program: @program, store: @store)
    GiftCards::Fund.call(gift_card: card, amount_cents: 5000, store: @store, performed_by: @actor)
    @program.update!(maximum_balance_cents: 50)
    sale = mixed_gift_card_and_cash_sale(card: card, gift_cents: 100)

    refund_txn = start_linked_return(sale)
    error = assert_raises(Pos::Error) do
      Pos::AddStoredValueRefundTender.call(
        transaction: refund_txn,
        actor: @actor,
        expected_lock_version: refund_txn.lock_version,
        tender_type: @gift_card_type,
        amount_cents: 100,
        destination_mode: "new_gift_card",
        gift_card_program: @program
      )
    end
    assert_match(/maximum balance/, error.message)
  end

  test "v2 completed envelopes remain acceptable after the v3 signed-net rewrite" do
    payload = JSON.parse(File.read(Rails.root.join("test/fixtures/files/pos/completed_pos_operation_v2/cash_sale.json")))
    assert_equal 2, payload.fetch("schema_version")
    Pos::CompletedTransactionFacts.new(payload).verify!
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

  def mixed_gift_card_and_cash_sale(card:, gift_cents:)
    transaction = start_sale
    Pos::AddStoredValueTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: @gift_card_type,
      amount_cents: gift_cents,
      card_number: card.number
    )
    Pos::TenderCash.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: Pos::Support.remaining_payment_cents(transaction)
    )
    complete_current!(transaction.reload).transaction
  end

  def start_linked_return(sale)
    refund_txn = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: refund_txn,
      actor: @actor,
      expected_lock_version: refund_txn.lock_version,
      original_line: sale.pos_transaction_lines.first,
      quantity: 1,
      reason_code: "changed_mind"
    )
    refund_txn.reload
  end

  def build_reload_ticket(card, amount_cents, session:)
    transaction = Pos::StartTransaction.call(session: session, actor: @actor)
    Pos::AddStoredValueIssuance.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      issuance_type: "reload",
      amount_cents: amount_cents,
      card_number: card.number
    )
    Pos::TenderCash.call(
      transaction: transaction.reload,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: amount_cents
    )
    transaction.reload
  end

  def complete_current!(transaction, expected_signed_net_cents: transaction.signed_net_cents)
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
