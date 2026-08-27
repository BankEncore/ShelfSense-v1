# frozen_string_literal: true

require "test_helper"

class PosTransactionHistoryTest < ActionDispatch::IntegrationTest
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 8)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @context = pos_open_context(store: @store, actor: @actor, register: @register)
    sign_in_as("admin")
  end

  test "cashier can search and view history without an open session" do
    transaction = complete_cash_sale!
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_hist")
    delete session_path
    sign_in_as("clerk_hist")

    get pos_transactions_path
    assert_response :success
    assert_select "a", text: transaction.transaction_reference
    refute PosSession.open.exists?(cashier_user: clerk)

    get pos_transaction_path(transaction)
    assert_response :success
    assert_match transaction.transaction_reference, response.body
    assert_match "Example Book", response.body
    assert_match "REPRINT", response.body
    assert_select ".pos-receipt__reprint", text: "*** REPRINT ***"
    assert_nil session[:pos_register_id]
  end

  test "another cashier at the same store can view and leftover filters do not hide an exact reference" do
    transaction = complete_cash_sale!
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_b")
    delete session_path
    sign_in_as("clerk_b")

    get pos_transactions_path, params: {
      transaction_reference: transaction.transaction_reference.downcase,
      business_date: "2020-01-01",
      receipt_sequence: "999"
    }
    assert_response :success
    assert_select "a", text: transaction.transaction_reference

    get pos_transaction_path(transaction)
    assert_response :success
    assert_match pos_cashier_name_for(transaction), response.body
  end

  test "other store and missing pos.transact cannot view history" do
    transaction = complete_cash_sale!
    east = Store.create!(store_number: "2", code: "east", name: "East Store", legal_name: "Example Books LLC", timezone: "America/New_York", country_code: "US")
    pos_transacting_user(store: east, assigned_by: @actor, username: "east_clerk")
    delete session_path
    sign_in_as("east_clerk")

    get pos_transactions_path
    assert_response :success
    assert_select "a", text: transaction.transaction_reference, count: 0

    get pos_transaction_path(transaction)
    assert_response :not_found

    User.create!(
      username: "no_pos",
      display_name: "No POS",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    delete session_path
    sign_in_as("no_pos")
    get pos_transactions_path
    assert_redirected_to root_path
  end

  test "historical show does not rebind the cashier register session" do
    other_register = Register.create!(store: @store, register_number: 2, name: "Back")
    other_context = pos_open_context(store: @store, actor: @actor, register: other_register)
    transaction = complete_cash_sale!(session: other_context[:session], actor: @actor)
    post pos_register_enter_path, params: {
      register_id: @register.id,
      opening_float: "0.00",
      confirmed_business_date: @context[:period].business_date.iso8601
    }
    assert_equal @register.id.to_s, session[:pos_register_id].to_s

    get pos_transaction_path(transaction)
    assert_response :success
    assert_equal @register.id.to_s, session[:pos_register_id].to_s
  end

  test "history list shows signed net and detail offers Return items without opening a session" do
    transaction = complete_cash_sale!
    pos_close_session!(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 0
    )
    assert_nil session[:pos_register_id]

    get pos_transactions_path
    assert_response :success
    assert_select "th", text: "Net"
    assert_match format_signed(transaction.signed_net_cents), response.body
    assert_nil session[:pos_register_id]

    get pos_transaction_path(transaction)
    assert_response :success
    assert_match "Sales tax", response.body
    assert_match "Sales total", response.body
    assert_match "Sold 1", response.body
    assert_match "Remaining 1", response.body
    assert_select "a", text: "Return items"
    assert_nil session[:pos_register_id]
    refute PosSession.open.exists?
  end

  test "history keeps snapshots after live catalog and user changes and reprint has no commercial effect" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax, name: "Used Book")
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    transaction.reload
    Pos::AddTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "card"),
      amount_cents: transaction.total_cents,
      external_reference: "AUTH-77"
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    transaction.reload
    original_description = transaction.pos_transaction_lines.first.merchandise_snapshot.fetch("description")
    unit_identifier = unit.unit_identifier

    used_variant.product.update!(name: "Renamed Used Book")
    TenderType.find_by!(code: "card").update!(name: "Bank Card")
    @actor.reload.update!(display_name: "Renamed Admin")
    PosTransaction.where(id: transaction.id).update_all(cashier_name_snapshot: nil)
    transaction.reload

    counts = commercial_counts
    get pos_transaction_path(transaction)
    assert_response :success
    assert_match original_description, response.body
    assert_match unit_identifier, response.body
    assert_match "External Card", response.body
    assert_match "AUTH-77", response.body
    assert_match "Not captured", response.body
    refute_match "Renamed Used Book", response.body
    refute_match "Bank Card", response.body
    assert_select ".pos-history__header dd", text: "Not captured"
    assert_select ".pos-receipt__print", text: /AUTH-77/, count: 0
    assert_select ".pos-receipt__reprint", text: "*** REPRINT ***"
    assert_equal counts, commercial_counts
    assert_equal transaction.receipt_sequence, transaction.reload.receipt_sequence
  end

  test "inactive register remains listed for history filters" do
    other_register = Register.create!(store: @store, register_number: 2, name: "Back")
    other_context = pos_open_context(store: @store, actor: @actor, register: other_register)
    sale = insert_completed_transaction!(
      session: other_context[:session],
      receipt_sequence: 3,
      completed_at: Time.utc(2026, 8, 18, 15, 0, 0)
    )
    other_register.update_column(:active, false)

    get pos_transactions_path, params: { register_id: other_register.id }
    assert_response :success
    assert_select "a", text: sale.transaction_reference
    assert_select "option[value='#{other_register.id}']"
  end

  test "history does not substitute live product names when the merchandise snapshot is missing" do
    transaction = complete_cash_sale!
    line = transaction.pos_transaction_lines.first
    PosTransactionLine.where(id: line.id).update_all(merchandise_snapshot: {})
    @variant.product.update!(name: "Live Catalog Name After History")

    get pos_transaction_path(transaction)
    assert_response :success
    assert_match "Description not captured", response.body
    refute_match "Live Catalog Name After History", response.body
    assert_select ".pos-history__line-main", text: /Example Book/, count: 0
    assert_select ".pos-receipt__line-description", text: /Example Book/, count: 0
    assert_select ".pos-receipt__print", text: /Description unavailable/
  end

  test "history register link resumes the bound session when the cashier has several open" do
    other_register = Register.create!(store: @store, register_number: 2, name: "Back")
    pos_open_context(store: @store, actor: @actor, register: other_register)
    assert_equal 2, PosSession.open.where(store: @store, cashier_user: @actor).count

    get pos_transactions_path
    assert_response :success
    assert_select "a[href='#{pos_path}']", text: "Resume"

    post pos_register_enter_path, params: {
      register_id: other_register.id,
      opening_float: "0.00",
      confirmed_business_date: @context[:period].business_date.iso8601
    }
    assert_equal other_register.id.to_s, session[:pos_register_id].to_s

    get pos_transactions_path
    assert_response :success
    assert_select "a[href='#{pos_register_workspace_path(register_id: other_register.id)}']", text: "Resume"
    assert_select "a[href='#{pos_register_workspace_path(register_id: @register.id)}']", text: "Resume", count: 0
  end

  test "transaction history index exposes search landmarks for workflow layer" do
    transaction = complete_cash_sale!
    get pos_transactions_path
    assert_response :success
    assert_select "main"
    assert_select "h1", text: /Transactions/i
    assert_select "form[action='#{pos_transactions_path}']"
    assert_select "a", text: transaction.transaction_reference
  end

  test "transaction detail exposes immutable receipt structure for workflow layer" do
    transaction = complete_cash_sale!
    get pos_transaction_path(transaction)
    assert_response :success
    assert_select ".pos-receipt"
    assert_select ".pos-receipt__line-description", text: /Example Book/
    assert_match transaction.transaction_reference, response.body
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def complete_cash_sale!(session: @context[:session], actor: @actor, variant: @variant)
    transaction = Pos::StartTransaction.call(session: session, actor: actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      identifier: variant.sku
    )
    transaction.reload
    Pos::TenderCash.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    transaction.reload
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    transaction.reload
  end

  def pos_cashier_name_for(transaction)
    transaction.cashier_name_snapshot.presence || "Not captured"
  end

  def format_signed(cents)
    return "$0.00" if cents.to_i.zero?

    prefix = cents.positive? ? "+" : "-"
    absolute = cents.abs
    "#{prefix}$#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end

  def commercial_counts
    {
      transactions: PosTransaction.count,
      tenders: PosTender.count,
      ledger: InventoryLedgerEntry.count,
      outbox: OutboxMessage.count
    }
  end
end
