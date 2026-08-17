# frozen_string_literal: true

require "test_helper"

class PosRegisterTest < ActionDispatch::IntegrationTest
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
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    sign_in_as("admin")
  end

  test "get enter does not create a session or transaction" do
    get pos_register_enter_path, params: { register_id: @register.id }
    assert_response :success
    assert_equal 0, PosSession.count
    assert_equal 0, PosTransaction.count
    assert_match "Opening float", response.body
  end

  test "post enter then workspace sale tender and complete" do
    post pos_register_enter_path, params: { register_id: @register.id, opening_float: "50.00" }
    assert_redirected_to pos_register_workspace_path
    follow_redirect!
    assert_response :success
    transaction = PosTransaction.working.find_by!(pos_session: PosSession.open.find_by!(register: @register))
    assert_match "SALE ENTRY", response.body
    assert_match "Scan or identifier", response.body

    get pos_register_workspace_path
    assert_response :success
    assert_equal 1, PosTransaction.working.where(pos_session: transaction.pos_session).count

    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    assert_response :success
    transaction.reload
    assert_equal 1, transaction.pos_transaction_lines.count

    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    assert_response :success
    transaction.reload
    assert_equal 1, transaction.pos_tenders.count
    assert_match "CHANGE", response.body
    assert_select "input[name='completion_operation_id']"

    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_register_complete_path, params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    }
    assert_redirected_to pos_completed_transaction_path(transaction)
    follow_redirect!
    assert_response :success
    assert_match "Sale complete", response.body
    assert_match transaction.reload.transaction_reference, response.body
    assert_match "New sale", response.body

    get pos_register_workspace_path
    assert_redirected_to pos_register_enter_path(register_id: @register.id)

    post pos_register_continue_path
    assert_redirected_to pos_register_workspace_path
    follow_redirect!
    assert_response :success
    assert_equal 1, PosTransaction.working.where(pos_session: transaction.pos_session).count
    refute_equal transaction.id, PosTransaction.working.find_by!(pos_session: transaction.pos_session).id
  end

  test "occupied register is denied on get and post enter" do
    Pos::EnterRegister.call(store: @store, register: @register, actor: @actor, opening_float_cents: 0)
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_pos")
    delete session_path
    sign_in_as("clerk_pos")

    get pos_register_enter_path, params: { register_id: @register.id }
    assert_response :success
    assert_match "is open for", response.body
    assert_select "input[type='submit'][value='Open register'][disabled]"

    post pos_register_enter_path, params: { register_id: @register.id, opening_float: "0.00" }
    assert_response :unprocessable_content
    assert_equal 1, PosSession.open.where(register: @register).count
    assert_equal @actor.id, PosSession.open.find_by!(register: @register).cashier_user_id
  end

  test "user without store access cannot enter the register" do
    User.create!(
      username: "no_pos",
      display_name: "No POS",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    delete session_path
    post session_path, params: { session: { username: "no_pos", password: "correct-horse-battery" } }
    get pos_register_enter_path
    assert_redirected_to root_path
    assert_equal 0, PosSession.count
  end

  test "second cashier cannot mutate another cashier workspace" do
    result = Pos::EnterRegister.call(store: @store, register: @register, actor: @actor, opening_float_cents: 0)
    Pos::AddMerchandise.call(
      transaction: result.transaction,
      actor: @actor,
      expected_lock_version: result.transaction.lock_version,
      identifier: @variant.sku
    )
    transaction = result.transaction.reload
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "other_ws")
    delete session_path
    sign_in_as("other_ws")

    post pos_register_merchandise_path, params: {
      identifier: @variant.sku,
      lock_version: transaction.lock_version,
      register_id: @register.id
    }
    assert_redirected_to pos_register_enter_path(register_id: @register.id)
    assert_equal 1, transaction.reload.pos_transaction_lines.count
  end

  test "abandon tender and cancel clear working tenders" do
    post pos_register_enter_path, params: { register_id: @register.id, opening_float: "0.00" }
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_abandon_tender_path, params: { lock_version: transaction.lock_version }
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert transaction.working?

    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_cancel_path, params: { lock_version: transaction.lock_version }
    assert_redirected_to pos_register_workspace_path
    assert transaction.reload.cancelled?
    assert_equal 0, transaction.pos_tenders.count
  end

  test "completed receipt is not found while working" do
    post pos_register_enter_path, params: { register_id: @register.id, opening_float: "0.00" }
    transaction = PosTransaction.working.find_by!(register: @register)
    get pos_completed_transaction_path(transaction)
    assert_response :not_found
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
