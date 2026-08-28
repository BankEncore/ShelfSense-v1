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
    assert_redirected_to pos_path(register_id: @register.id)
    follow_redirect!
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
    assert_select ".pos-summary-rail #pos_totals"
    assert_select ".pos-summary-rail #pos_tenders"
    assert_select "#pos_totals ~ #pos_tenders"
    assert_select "#pos_totals", text: /Net/
    refute_match(/\bSales\b/, css_select("#pos_totals").text)

    get pos_register_workspace_path
    assert_response :success
    assert_equal 1, PosTransaction.working.where(pos_session: transaction.pos_session).count

    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    assert_response :success
    transaction.reload
    assert_equal 1, transaction.pos_transaction_lines.count
    assert_select "#pos_totals", text: /Merchandise/
    assert_select "#pos_totals", text: /Illinois State/
    assert_select "#pos_tenders ~ .pos-settlement"
    assert_match "Amount due", css_select(".pos-settlement").text
    refute_match(/\bSales\b/, css_select("#pos_totals").text)

    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    assert_response :success
    transaction.reload
    assert_equal 1, transaction.pos_tenders.count
    assert_match "CHANGE", response.body
    assert_select "input[name='completion_operation_id']"

    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents,
      amount_presented_cents: 2500
    }
    assert_redirected_to pos_completed_transaction_path(transaction)
    follow_redirect!
    assert_response :success
    assert_match "Transaction complete", response.body
    assert_match "Sales subtotal", response.body
    assert_match "Sales tax", response.body
    assert_match "Sales total", response.body
    assert_match transaction.reload.transaction_reference, response.body
    assert_match "New transaction", response.body
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

  test "workspace serializes cashier tender identities as JSON including names with pipes" do
    card = TenderType.find_by!(code: "card")
    cash = TenderType.find_by!(code: "cash")
    card.update!(name: "Credit | Debit")
    voucher = TenderType.create!(
      code: "voucher",
      name: "Voucher",
      behavioral_category: "other",
      external_reference_policy: "omitted",
      active: true
    )
    campus = TenderType.create!(
      code: "campus_charge",
      name: "Campus Charge",
      behavioral_category: "other",
      external_reference_policy: "required",
      active: true
    )

    post pos_register_enter_path, params: enter_params(opening_float: "50.00")
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    assert_response :success

    payload = JSON.parse(css_select("#pos_workspace").first["data-register-workspace-tender-types-value"])
    by_id = payload.index_by { |row| row.fetch("id") }
    assert_equal "Credit | Debit", by_id.fetch(card.id.to_s).fetch("name")
    assert_equal "card", by_id.fetch(card.id.to_s).fetch("category")
    assert_equal "optional", by_id.fetch(card.id.to_s).fetch("reference_policy")
    assert_equal "omitted", by_id.fetch(cash.id.to_s).fetch("reference_policy")
    assert_equal "omitted", by_id.fetch(voucher.id.to_s).fetch("reference_policy")
    assert_equal "required", by_id.fetch(campus.id.to_s).fetch("reference_policy")
    assert_equal true, by_id.fetch(cash.id.to_s).fetch("allows_refund")
    assert_equal true, by_id.fetch(card.id.to_s).fetch("allows_refund")
    assert_equal false, by_id.fetch(voucher.id.to_s).fetch("allows_refund")
    gift_card = TenderType.find_by!(code: "gift_card")
    assert_equal "gift_card", by_id.fetch(gift_card.id.to_s).fetch("stored_value_account_type")
    assert_equal %w[cash card check stored_value stored_value stored_value other other], payload.map { |row| row.fetch("category") }
  end

  test "workspace can take Card then Cash and complete" do
    post pos_register_enter_path, params: enter_params(opening_float: "50.00")
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    card = TenderType.find_by!(code: "card")
    post pos_register_tender_path, params: {
      tender_amount: "10.00",
      tender_type_id: card.id,
      external_reference: "AUTH-9",
      lock_version: transaction.lock_version
    }
    assert_response :success
    assert_match "External Card", response.body
    assert_match "Amount due", response.body
    transaction.reload
    cash = TenderType.find_by!(code: "cash")
    post pos_register_tender_path, params: {
      tender_amount: "25.00",
      tender_type_id: cash.id,
      lock_version: transaction.lock_version
    }
    assert_response :success
    assert_match "CHANGE", response.body
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents
    }
    assert_redirected_to pos_completed_transaction_path(transaction)
    follow_redirect!
    assert_match "External Card", response.body
    assert_match "AUTH-9", response.body
    assert_select ".pos-receipt__print", text: /AUTH-9/, count: 0
    completed = transaction.reload
    assert_equal %w[card cash], completed.pos_tenders.ordered.map(&:behavioral_category)
  end

  test "occupied register is denied on get and post enter" do
    Pos::EnterRegister.call(store: @store, register: @register, actor: @actor, opening_float_cents: 0)
    other = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_pos")
    delete session_path
    sign_in_as("clerk_pos")

    get pos_register_enter_path, params: { register_id: @register.id }
    follow_redirect!
    assert_response :success
    assert_match "is open for", response.body
    assert_select "h1", text: "Register in use"

    post pos_register_enter_path, params: enter_params
    assert_response :unprocessable_content
    assert_select "h1", text: "Register in use"
    assert_match "is open for #{@actor.display_name}", response.body
    assert_equal 1, PosSession.open.where(register: @register).count
    assert_equal @actor.id, PosSession.open.find_by!(register: @register).cashier_user_id
  end

  test "user with multiple stores is sent to store selection on enter" do
    Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store", legal_name: "Example Books LLC",
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
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_abandon_tender_path, params: { lock_version: transaction.lock_version }
    transaction.reload
    assert_equal 0, transaction.pos_tenders.count
    assert transaction.working?

    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
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
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    params = {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents,
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
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    Pos::CompleteTransaction.call(
      transaction: transaction,
      actor: @actor,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents
    )
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents,
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

    post pos_register_tender_path, params: { tender_amount: "abc", lock_version: transaction.lock_version }
    assert_response :success
    assert_match "CASH TENDER", response.body
    assert_match(/not a valid amount/i, response.body)
    assert_select "#pos-command-field[value='abc']"

    post pos_register_tender_path, params: { tender_amount: "0.01", lock_version: transaction.reload.lock_version }
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
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = SecureRandom.uuid_v7
    payload = Pos::CompleteTransaction.command_payload(
      transaction: transaction,
      operation_id: operation_id,
      expected_lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents
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
    follow_redirect!
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
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents,
      amount_presented_cents: 2500
    }
    follow_redirect!
    assert_match @store.name, response.body

    east = Store.create!(
      store_number: "2",
      code: "east",
      name: "East Store", legal_name: "Example Books LLC",
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
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    complete_params = {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents, expected_signed_net_cents: transaction.signed_net_cents,
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

  test "workspace exposes controlled-action overlay and direct price override" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    assert_response :success
    assert_select "button", text: "Price (F6)"
    assert_select "button", text: "Discount (F7)"
    assert_select "button", text: "Tax Class"
    assert_select "#pos_control_overlay"
    assert_select "#pos-approver-username"
    assert_select "#pos-approver-password"
    refute_includes response.body, "Return (F"
    refute_includes response.body, "Post-void"

    line = transaction.reload.pos_transaction_lines.first
    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "shelf_price_mismatch",
      selling_price: "15.00"
    }
    assert_response :success
    line.reload
    assert_equal 1500, line.selling_unit_price_cents
    assert_equal 1999, line.reference_unit_price_cents
    assert_match "Override", response.body
  end

  test "associate override stays on the workspace and requires a manager password" do
    associate = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_ui")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_ui")
    delete session_path
    sign_in_as("clerk_ui")

    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    line = transaction.reload.pos_transaction_lines.first

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "15.00"
    }
    assert_response :success
    assert_equal 1999, line.reload.selling_unit_price_cents
    assert_match(/approver credentials/, response.body)
    assert_equal associate.id, User.find_by!(username: "clerk_ui").id

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.reload.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "15.00",
      approver_username: "mgr_ui",
      approver_password: "correct-horse-battery"
    }
    assert_response :success
    assert_equal 1500, line.reload.selling_unit_price_cents
    assert_equal associate.id, transaction.reload.cashier_user_id
    assert_response :success
  end

  test "turbo stream overlay error updates dialog feedback without replacing the workspace" do
    pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_overlay")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_overlay")
    delete session_path
    sign_in_as("clerk_overlay")

    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    line = transaction.reload.pos_transaction_lines.first

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "15.00",
      approver_username: "mgr_overlay",
      approver_password: "wrong-password-secret"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
    assert_equal 1999, line.reload.selling_unit_price_cents
    assert_match(/approver credentials/, response.body)
    assert_includes response.body, 'target="pos-control-feedback"'
    refute_includes response.body, 'target="pos_workspace"'
    refute_includes response.body, "wrong-password-secret"
  end

  test "stale overlay submission still replaces the workspace" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    line = transaction.reload.pos_transaction_lines.first

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version - 1,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "15.00"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="pos_workspace"'
    assert_match(/This sale was changed/, response.body)
  end

  test "discount apply ignores a leftover malformed selling_price" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    line = transaction.reload.pos_transaction_lines.first

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version,
      line_id: line.id,
      action_type: "line_discount",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "abc",
      discount_percent: "10.00"
    }
    assert_response :success
    refute_match(/not a valid amount/, response.body)
    assert_equal 1000, line.reload.manual_discount_basis_points
    assert_equal 1999, line.selling_unit_price_cents
  end

  test "controlled-action remove ignores leftover commercial values" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    line = transaction.reload.pos_transaction_lines.first
    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "15.00"
    }
    assert_equal 1500, line.reload.selling_unit_price_cents

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.reload.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "remove",
      selling_price: "abc",
      discount_percent: "not-a-number",
      tax_class_id: "nope"
    }
    assert_response :success
    refute_match(/not a valid amount/, response.body)
    line.reload
    assert_equal line.reference_unit_price_cents, line.selling_unit_price_cents
    assert_equal 0, line.pos_controlled_actions.count
  end

  test "shared lookup code returns product choices and selecting one resolves without adding" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 4)
    @variant.product.update!(lookup_code: "SHARED", brand_name: "Acme")
    other.product.update!(lookup_code: "SHARED")

    post pos_register_enter_path, params: enter_params
    follow_redirect!
    assert_select "#pos_product_overlay[hidden]"
    transaction = PosTransaction.working.find_by!(register: @register)

    get pos_register_merchandise_resolve_path, params: { identifier: "shared" }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "product_choice_required", body.fetch("outcome")
    products = body.fetch("products")
    assert_equal [ @variant.product.id, other.product.id ].sort, products.map { |row| row.fetch("id") }.sort
    chosen = products.find { |row| row.fetch("id") == @variant.product.id }
    assert_equal @variant.product.primary_identifier, chosen.fetch("primary_identifier")
    assert_equal "SHARED", chosen.fetch("lookup_code")
    assert_equal "Acme", chosen.fetch("brand_name")
    assert_equal 0, transaction.reload.pos_transaction_lines.count

    get pos_register_merchandise_resolve_path, params: { product_id: @variant.product.id }, as: :json
    assert_response :success
    assert_equal "addable_variant", response.parsed_body.fetch("outcome")
    assert_equal 0, transaction.reload.pos_transaction_lines.count
  end

  test "resolve and search are read-only and open-price apply does not write a price_override" do
    open_price = pos_sellable_variant(actor: @actor, tax_class: @tax, pricing_method: "open_price", name: "Open Book")
    open_quantity_stock(store: @store, variant: open_price, actor: @actor, quantity: 3)
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    transaction.reload
    post pos_register_tender_path, params: {
      tender_amount: "10.00",
      tender_type_id: TenderType.find_by!(code: "card").id,
      external_reference: "AUTH-9",
      lock_version: transaction.lock_version
    }
    transaction.reload
    assert_equal 1, transaction.pos_tenders.count

    get pos_register_merchandise_resolve_path, params: { identifier: open_price.sku }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "open_price_required", body.fetch("outcome")
    transaction.reload
    assert_equal 1, transaction.pos_tenders.count
    assert_equal 1, transaction.pos_transaction_lines.count

    get pos_register_merchandise_search_path, params: { name: "Open Book" }, as: :json
    assert_response :success
    results = response.parsed_body.fetch("results")
    assert results.is_a?(Array)
    assert results.any? { |row| row.fetch("id") == open_price.id }

    post pos_register_merchandise_path, params: {
      product_variant_id: open_price.id,
      selling_price: "5.00",
      lock_version: transaction.lock_version
    }
    assert_response :success
    transaction.reload
    open_line = transaction.pos_transaction_lines.find_by!(product_variant_id: open_price.id)
    assert_equal "open_price", open_line.pricing_method_snapshot
    assert_equal 500, open_line.reference_unit_price_cents
    assert_equal 500, open_line.selling_unit_price_cents
    assert_equal 0, open_line.pos_controlled_actions.where(action_type: "price_override").count
    assert_equal 0, transaction.pos_tenders.count
  end

  test "linked return lookup is read-only get" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    lock = transaction.lock_version
    get pos_register_linked_return_lookup_path, params: { q: "not-a-receipt" }, as: :json
    assert_response :success
    assert_equal "empty", response.parsed_body.fetch("outcome")
    transaction.reload
    assert_equal lock, transaction.lock_version
    assert_equal 0, transaction.pos_transaction_lines.count
  end

  test "resolve after store switch does not treat a sellable sku as missing" do
    west = Store.create!(
      store_number: "2",
      code: "west",
      name: "West Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    west_register = Register.create!(store: west, register_number: 1, name: "West Front")
    ensure_initialized_safe!(store: west, actor: @actor)
    post store_selection_path, params: { store_id: west.id }
    post pos_register_enter_path, params: {
      register_id: west_register.id,
      opening_float: "0.00",
      confirmed_business_date: BusinessDate.for_store(west).iso8601
    }
    assert_equal west_register.id.to_s, session[:pos_register_id].to_s

    post store_selection_path, params: { store_id: @store.id }
    assert_nil session[:pos_register_id]

    post pos_register_enter_path, params: enter_params
    follow_redirect!
    assert_response :success
    assert_match "register/merchandise_resolve?register_id=#{@register.id}", response.body
    bound = session[:pos_register_id].to_s

    get pos_register_merchandise_resolve_path, params: { identifier: @variant.sku, register_id: @register.id }, as: :json
    assert_response :success
    assert_equal "addable_variant", response.parsed_body.fetch("outcome")
    assert_equal @variant.id, response.parsed_body.dig("variant", "id")
    assert_equal bound, session[:pos_register_id].to_s

    other = Register.create!(store: @store, register_number: 2, name: "Back")
    get pos_register_merchandise_resolve_path, params: { identifier: @variant.sku, register_id: other.id }, as: :json
    assert_response :conflict
    assert_equal bound, session[:pos_register_id].to_s
    assert_equal "open a register to continue", response.parsed_body.fetch("message")
  end

  test "read-only workspace gets do not bind the register" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    bound = session[:pos_register_id].to_s
    other = Register.create!(store: @store, register_number: 9, name: "Unused")

    get pos_register_workspace_path, params: { register_id: @register.id }
    assert_response :success
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_merchandise_resolve_path, params: { identifier: @variant.sku, register_id: @register.id }, as: :json
    assert_response :success
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_merchandise_search_path, params: { name: "Example", register_id: @register.id }, as: :json
    assert_response :success
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_linked_return_lookup_path, params: { q: "not-a-receipt", register_id: @register.id }, as: :json
    assert_response :success
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_workspace_path, params: { register_id: other.id }
    assert_redirected_to pos_register_enter_path(register_id: other.id)
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_merchandise_resolve_path, params: { identifier: @variant.sku, register_id: other.id }, as: :json
    assert_response :conflict
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_merchandise_search_path, params: { name: "Example", register_id: other.id }, as: :json
    assert_response :conflict
    assert_equal bound, session[:pos_register_id].to_s

    get pos_register_linked_return_lookup_path, params: { q: @variant.sku, register_id: other.id }, as: :json
    assert_response :conflict
    assert_equal bound, session[:pos_register_id].to_s
  end

  test "completion and history keep performer and approver provenance" do
    clerk = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_prov")
    manager = pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_prov")
    delete session_path
    sign_in_as("clerk_prov")

    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    post pos_register_merchandise_path, params: { identifier: @variant.sku, lock_version: transaction.lock_version }
    line = transaction.reload.pos_transaction_lines.first

    post pos_register_controlled_action_path, params: {
      lock_version: transaction.lock_version,
      line_id: line.id,
      action_type: "price_override",
      operation: "apply",
      reason_code: "damaged",
      selling_price: "15.00",
      approver_username: "mgr_prov",
      approver_password: "correct-horse-battery"
    }
    assert_response :success
    transaction.reload
    post pos_register_tender_path, params: { tender_amount: "25.00", lock_version: transaction.lock_version }
    transaction.reload
    operation_id = css_select("input[name='completion_operation_id']").first["value"]
    post pos_transaction_complete_path(transaction), params: {
      completion_operation_id: operation_id,
      lock_version: transaction.lock_version,
      expected_total_cents: transaction.total_cents,
      expected_signed_net_cents: transaction.signed_net_cents,
      amount_presented_cents: 2500
    }
    assert_redirected_to pos_completed_transaction_path(transaction)
    follow_redirect!
    assert_response :success
    assert_match "Price override", response.body
    assert_match "Performed by", response.body
    assert_match clerk.display_name, response.body
    assert_match "Approved by", response.body
    assert_match manager.display_name, response.body
    assert_match "Damaged", response.body
    assert_select ".pos-receipt__print", text: /Price override/, count: 0
    assert_select ".pos-receipt__print", text: /Performed by/, count: 0
    assert_select ".pos-receipt__print", text: /Approved by/, count: 0

    get pos_transaction_path(transaction)
    assert_response :success
    assert_match "Price override", response.body
    assert_match "Performed by", response.body
    assert_match clerk.display_name, response.body
    assert_match "Approved by", response.body
    assert_match manager.display_name, response.body
    assert_match "Damaged", response.body
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
