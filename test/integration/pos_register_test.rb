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
    assert_select "input[name='confirmed_business_date']"
    assert_select "html:not([data-turbo])"
    assert_select "script[type=module]", text: /import "pos"/
  end

  test "post enter then workspace sale tender and complete" do
    post pos_register_enter_path, params: enter_params(opening_float: "50.00")
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
    post pos_transaction_complete_path(transaction), params: {
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
    assert_match "Print receipt", response.body
    assert_match "Close register", response.body

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

    post pos_register_enter_path, params: enter_params
    assert_response :unprocessable_content
    assert_equal 1, PosSession.open.where(register: @register).count
    assert_equal @actor.id, PosSession.open.find_by!(register: @register).cashier_user_id
  end

  test "user with multiple stores is sent to store selection on enter" do
    Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )

    get pos_register_enter_path
    assert_redirected_to new_store_selection_path
    assert_equal 0, PosSession.count
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
    post pos_register_enter_path, params: enter_params
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
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    get pos_completed_transaction_path(transaction)
    assert_response :not_found
  end

  test "complete retry of an already completed transaction shows that receipt" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    params = {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    }
    post pos_transaction_complete_path(transaction), params: params
    assert_redirected_to pos_completed_transaction_path(transaction)
    assert transaction.reload.completed?

    post pos_transaction_complete_path(transaction), params: params
    assert_redirected_to pos_completed_transaction_path(transaction)
    follow_redirect!
    assert_response :success
    assert_match transaction.transaction_reference, response.body
    assert_equal 1, PosTransaction.completed.where(id: transaction.id).count
  end

  test "complete does not redirect to enter when the working transaction is gone" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    )
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    }
    assert_redirected_to pos_completed_transaction_path(transaction)
    follow_redirect!
    assert_response :success
    assert_match transaction.reload.transaction_reference, response.body
  end

  test "invalid quantity stays in quantity and invalid cash stays in tender" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    line = transaction.pos_transaction_lines.first

    post pos_register_quantity_path, params: {
      line_id: line.id,
      quantity: "0",
      lock_version: transaction.lock_version
    }
    assert_response :success
    assert_match "QUANTITY", response.body
    assert_match "quantity must be positive", response.body
    assert_select "#pos-command-field[value='0']"

    post pos_register_tender_path, params: { amount_presented: "abc", lock_version: transaction.lock_version }
    assert_response :success
    assert_match "CASH TENDER", response.body
    assert_match(/not a valid amount/i, response.body)
    assert_select "#pos-command-field[value='abc']"

    post pos_register_tender_path, params: { amount_presented: "0.01", lock_version: transaction.reload.lock_version }
    assert_response :success
    assert_match "CASH TENDER", response.body
    assert_match(/amount due/i, response.body)
    assert transaction.reload.pos_tenders.empty?
  end

  test "unexpired in_flight completion does not auto submit" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = SecureRandom.uuid_v7
    payload = Pos::CompleteTransaction.command_payload(
      transaction: transaction,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    )
    Pos::OperationLease.begin!(
      register_id: transaction.register_id,
      operation_id: operation_id,
      command_payload: payload,
      store_id: transaction.store_id,
      pos_transaction_id: transaction.id
    )
    get pos_register_workspace_path
    assert_response :success
    assert_match "Completion is still processing", response.body
    assert_select "[data-register-workspace-auto-complete-value='false']"
    assert_select "input[name='completion_operation_id'][value='#{operation_id}']"
    assert_select "[data-register-workspace-target='retry']", count: 0
    assert_select "[data-register-workspace-target='abandonButton']", count: 0
    assert_select "[data-register-workspace-target='clientRecovery'][hidden]"
    assert_select "button[data-register-workspace-target='cancelButton'][disabled]"
  end

  test "opening a new period requires a confirmed business date" do
    post pos_register_enter_path, params: { register_id: @register.id, opening_float: "0.00" }
    assert_response :unprocessable_content
    assert_match(/business date confirmation is required/, response.body)
    assert_equal 0, PosReportingPeriod.where(register: @register).count
  end

  test "enter rejects a confirmed date that does not match an already open period" do
    Pos::OpenReportingPeriod.call(store: @store, register: @register, actor: @actor)
    post pos_register_enter_path, params: {
      register_id: @register.id,
      opening_float: "0.00",
      confirmed_business_date: (BusinessDate.for_store(@store) - 1.day).iso8601
    }
    assert_response :unprocessable_content
    assert_match(/already open on business date/, response.body)
    assert_equal 0, PosSession.where(register: @register).count
  end

  test "confirmed business date is rejected after the calendar boundary" do
    now = Time.current
    confirmed = BusinessDate.for_store(@store, at: now)
    get pos_register_enter_path, params: { register_id: @register.id }
    assert_response :success
    assert_select "input[name='confirmed_business_date'][value='#{confirmed.iso8601}']"

    travel_to now + 1.day do
      UserSession.where(user: @actor).update_all(last_seen_at: Time.current)
      post pos_register_enter_path, params: {
        register_id: @register.id,
        opening_float: "0.00",
        confirmed_business_date: confirmed.iso8601
      }
      assert_response :unprocessable_content
      assert_select "input[name='confirmed_business_date'][value='#{BusinessDate.for_store(@store).iso8601}']"
      assert_equal 0, PosReportingPeriod.where(register: @register).count
    end
  end

  test "completed receipt is scoped to the current store" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    }
    follow_redirect!
    assert_match @store.name, response.body

    east = Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store",
      timezone: "America/New_York",
      country_code: "US"
    )
    post store_selection_path, params: { store_id: east.id }
    get pos_completed_transaction_path(transaction)
    assert_response :not_found
  end

  test "complete retry after inventory failure does not re-tender" do
    post pos_register_enter_path, params: enter_params
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: { amount_presented: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    complete_params = {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      amount_presented_cents: 2500
    }

    Inventory::AdjustmentReasons.seed!
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "shrinkage"),
      quantity_delta: -5,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )

    post pos_transaction_complete_path(transaction), params: complete_params
    assert_response :success
    assert_match "Retry complete", response.body
    assert_select "input[name='completion_operation_id'][value='#{operation_id}']"
    assert transaction.reload.working?
    assert_equal 1, transaction.pos_tenders.count

    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    post pos_transaction_complete_path(transaction), params: complete_params
    assert_redirected_to pos_completed_transaction_path(transaction)
    assert transaction.reload.completed?
    assert_equal 1, transaction.pos_tenders.count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params(opening_float: "0.00")
    {
      register_id: @register.id,
      opening_float: opening_float,
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end
end
