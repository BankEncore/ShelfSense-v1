# frozen_string_literal: true

require "test_helper"

class PosReturnItemsTest < ActionDispatch::IntegrationTest
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
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 20)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @context = pos_open_context(store: @store, actor: @actor, register: @register)
    sign_in_as("admin")
  end

  test "return items get is read-only and other store is not found" do
    sale = complete_cash_sale!
    working_before = PosTransaction.working.count
    sessions_before = PosSession.count
    assert_nil session[:pos_register_id]

    get pos_transaction_return_items_path(sale)
    assert_response :success
    assert_match "Return items", response.body
    assert_match "Remaining 1", response.body
    assert_select "input[type='checkbox']"
    assert_nil session[:pos_register_id]
    assert_equal working_before, PosTransaction.working.count
    assert_equal sessions_before, PosSession.count

    east = Store.create!(store_number: "2", code: "east", name: "East Store", legal_name: "Example Books LLC", timezone: "America/New_York", country_code: "US")
    pos_transacting_user(store: east, assigned_by: @actor, username: "east_clerk")
    delete session_path
    sign_in_as("east_clerk")
    get pos_transaction_return_items_path(sale)
    assert_response :not_found
    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    assert_response :not_found
  end

  test "fully returned sale is not selectable and return transactions are not returnable" do
    sale = complete_cash_sale!
    original_line = sale.pos_transaction_lines.first
    returned = complete_linked_return!(original_line)

    get pos_transaction_path(sale)
    assert_response :success
    assert_match "Returned in full", response.body
    assert_select "a", text: returned.transaction_reference
    assert_select "a", text: "Return items", count: 0

    get pos_transaction_return_items_path(sale)
    assert_response :success
    assert_match "Returned in full", response.body
    assert_select "input[type='checkbox']", count: 0
    assert_select "input[type='submit'][value='Add to register']", count: 0

    get pos_transaction_path(returned)
    assert_response :success
    assert_match "RETURN", response.body
    assert_select "a", text: "Return items", count: 0
    assert_match sale.transaction_reference, response.body
  end

  test "used unit remaining quantity is fixed at one" do
    _used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    sale = complete_unit_sale!(unit)

    get pos_transaction_path(sale)
    assert_response :success
    assert_match unit.unit_identifier, response.body

    get pos_transaction_return_items_path(sale)
    assert_response :success
    assert_match unit.unit_identifier, response.body
    assert_select "input[type='hidden'][name=?][value='1']", "items[#{sale.pos_transaction_lines.first.id}][quantity]"
  end

  test "sole open session is the return target and post binds that register" do
    sale = complete_cash_sale!
    line = sale.pos_transaction_lines.first
    assert_nil session[:pos_register_id]
    assert_equal 1, PosSession.open.where(cashier_user: @actor).count

    post pos_transaction_return_items_path(sale), params: selected_item(line)
    assert_redirected_to pos_register_workspace_path(register_id: @register.id)
    assert_equal @register.id.to_s, session[:pos_register_id].to_s
    working = PosTransaction.working.find_by!(pos_session: @context[:session])
    assert_equal 1, working.pos_transaction_lines.count
    assert working.pos_transaction_lines.first.linked_return?
  end

  test "empty selection does not create a working transaction" do
    sale = complete_cash_sale!
    line = sale.pos_transaction_lines.first
    working_before = PosTransaction.working.count

    post pos_transaction_return_items_path(sale), params: selected_item(line, selected: "0")
    assert_response :unprocessable_entity
    assert_match "return items are required", response.body
    assert_equal working_before, PosTransaction.working.count
  end

  test "invalid return selection does not create a working transaction" do
    sale = complete_cash_sale!
    line = sale.pos_transaction_lines.first
    working_before = PosTransaction.working.count

    post pos_transaction_return_items_path(sale), params: selected_item(line, quantity: 99)
    assert_response :unprocessable_entity
    assert_match "return quantity exceeds remaining quantity", response.body
    assert_equal working_before, PosTransaction.working.count
  end

  test "submitted original lines must belong to the receipt" do
    sale = complete_cash_sale!
    other = complete_cash_sale!
    working_before = PosTransaction.working.count

    post pos_transaction_return_items_path(sale), params: selected_item(other.pos_transaction_lines.first)
    assert_response :unprocessable_entity
    assert_match "original sale line is missing", response.body
    assert_equal working_before, PosTransaction.working.count
  end

  test "bound open session wins over another open session for the same cashier" do
    sale = complete_cash_sale!
    other_register = Register.create!(store: @store, register_number: 2, name: "Back")
    other = pos_open_context(store: @store, actor: @actor, register: other_register)
    post pos_register_enter_path, params: {
      register_id: @register.id,
      opening_float: "0.00",
      confirmed_business_date: @context[:period].business_date.iso8601
    }
    assert_equal @register.id.to_s, session[:pos_register_id].to_s

    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    assert_redirected_to pos_register_workspace_path(register_id: @register.id)
    assert_equal @register.id.to_s, session[:pos_register_id].to_s
    refute PosTransaction.working.exists?(pos_session: other[:session])
    assert PosTransaction.working.find_by!(pos_session: @context[:session]).pos_transaction_lines.where(direction: "return").exists?
  end

  test "multiple unbound sessions do not pick an arbitrary return target" do
    sale = complete_cash_sale!
    other_register = Register.create!(store: @store, register_number: 2, name: "Back")
    pos_open_context(store: @store, actor: @actor, register: other_register)
    session[:pos_register_id] = nil
    working_before = PosTransaction.working.count

    get pos_transaction_return_items_path(sale)
    assert_response :success
    assert_match "Open a register before processing a return.", response.body
    assert_select "input[type='submit'][value='Add to register']", count: 0

    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    assert_response :unprocessable_entity
    assert_match "Open a register before processing a return.", response.body
    assert_equal working_before, PosTransaction.working.count
    assert_equal 0, PosTransactionLine.where(direction: "return").count
  end

  test "session closed between get and post does not add a return line" do
    sale = complete_cash_sale!
    get pos_transaction_return_items_path(sale)
    assert_response :success
    Pos::CloseSession.call(
      session: @context[:session],
      actor: @actor,
      expected_lock_version: @context[:session].lock_version,
      closing_count_cents: 0
    )

    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    assert_response :unprocessable_entity
    assert_match "Open a register before processing a return.", response.body
    assert_equal 0, PosTransactionLine.where(direction: "return").count
  end

  test "batch add is all or nothing and reuses a working sale basket" do
    second = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Second Book")
    open_quantity_stock(store: @store, variant: second, actor: @actor, quantity: 5)
    sale = complete_two_line_sale!(second)
    first_line, second_line = sale.pos_transaction_lines.to_a
    post pos_register_enter_path, params: enter_params
    working = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: working.lock_version }
    working.reload
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: working.lock_version }
    working.reload
    assert working.pos_tenders.any?

    get pos_transaction_return_items_path(sale)
    assert_response :success
    assert_match "Adding return items will clear the current tender entries.", response.body

    post pos_transaction_return_items_path(sale), params: {
      items: {
        first_line.id => item_row(first_line, quantity: 1, reason_code: "changed_mind"),
        second_line.id => item_row(second_line, quantity: 1, reason_code: "bogus")
      }
    }
    assert_response :unprocessable_entity
    working.reload
    assert_equal 1, working.pos_transaction_lines.count
    assert_equal 0, working.pos_transaction_lines.where(direction: "return").count

    post pos_transaction_return_items_path(sale), params: {
      items: {
        first_line.id => item_row(first_line, quantity: 1, reason_code: "changed_mind"),
        second_line.id => item_row(second_line, quantity: 1, reason_code: "defective")
      }
    }
    assert_redirected_to pos_register_workspace_path(register_id: @register.id)
    working.reload
    assert_equal 3, working.pos_transaction_lines.count
    assert_equal 0, working.pos_tenders.count
    reasons = working.pos_transaction_lines.select(&:return?).map(&:return_reason_code).sort
    assert_equal %w[changed_mind defective], reasons
  end

  test "already in basket is disabled and rejected" do
    sale = complete_cash_sale!
    line = sale.pos_transaction_lines.first
    post pos_transaction_return_items_path(sale), params: selected_item(line)
    follow_redirect!

    get pos_transaction_return_items_path(sale)
    assert_response :success
    assert_match "Already in current basket", response.body
    assert_select "input[type='checkbox']", count: 0

    post pos_transaction_return_items_path(sale), params: selected_item(line)
    assert_response :unprocessable_entity
    assert_match "already on this transaction", response.body
    working = PosTransaction.working.find_by!(register: @register)
    assert_equal 1, working.pos_transaction_lines.count
  end

  test "another cashier at the store may return" do
    sale = complete_cash_sale!
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_return")
    clerk_register = Register.create!(store: @store, register_number: 3, name: "Side")
    clerk_context = pos_open_context(store: @store, actor: clerk, register: clerk_register)
    delete session_path
    sign_in_as("clerk_return")

    post pos_transaction_return_items_path(sale), params: selected_item(sale.pos_transaction_lines.first)
    assert_redirected_to pos_register_workspace_path(register_id: clerk_register.id)
    working = PosTransaction.working.find_by!(pos_session: clerk_context[:session])
    assert_equal clerk.id, working.cashier_user_id
    assert working.pos_transaction_lines.first.linked_return?
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params
    {
      register_id: @register.id,
      opening_float: "0.00",
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end

  def item_row(line, quantity:, reason_code:, reason_note: "", selected: "1")
    {
      selected: selected,
      original_line_id: line.id,
      quantity: quantity,
      reason_code: reason_code,
      reason_note: reason_note
    }
  end

  def selected_item(line, **attrs)
    { items: { line.id => item_row(line, quantity: 1, reason_code: "changed_mind", **attrs) } }
  end

  def complete_cash_sale!(session: @context[:session], actor: @actor, variant: @variant, quantity: 1)
    transaction = Pos::StartTransaction.call(session: session, actor: actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      identifier: variant.sku,
      quantity: quantity
    )
    settle_and_complete!(transaction.reload, actor: actor)
  end

  def complete_two_line_sale!(second_variant)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: @variant.sku
    )
    transaction.reload
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: second_variant.sku
    )
    settle_and_complete!(transaction.reload)
  end

  def complete_unit_sale!(unit)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddMerchandise.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      identifier: unit.unit_identifier
    )
    settle_and_complete!(transaction.reload)
  end

  def complete_linked_return!(original_line)
    transaction = Pos::StartTransaction.call(session: @context[:session], actor: @actor)
    Pos::AddLinkedReturnLine.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      original_line: original_line,
      quantity: original_line.quantity,
      reason_code: "changed_mind"
    )
    transaction.reload
    Pos::AddRefundTender.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      tender_type: TenderType.find_by!(code: "cash"),
      amount_cents: -transaction.signed_net_cents
    )
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: @actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents
    )
    transaction.reload
  end

  def settle_and_complete!(transaction, actor: @actor)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: transaction.total_cents
    )
    Pos::CompleteTransaction.call(
      transaction: transaction.reload,
      actor: actor,
      operation_id: SecureRandom.uuid_v7,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents
    )
    transaction.reload
  end
end
