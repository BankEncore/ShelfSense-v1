# frozen_string_literal: true

require "application_system_test_case"

class PosRegisterWorkspaceTest < ApplicationSystemTestCase
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
  end

  test "cashier can sell cash and start a new sale from the receipt" do
    open_register
    add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_text "2"
    assert_text "SALE ENTRY"

    click_on "Tender (+)"
    assert_text "CASH TENDER"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Sale complete", wait: 10
    assert_equal 1, PosTransaction.completed.where(register: @register).count
    assert_text "New sale"
    send_keys :enter
    assert_text "Sale complete"
    click_on "New sale"
    assert_text "SALE ENTRY"
    assert_no_text "Example Book"
  end

  test "delete and hyphen edit the identifier and f8 removes the selected line" do
    open_register
    field = find("#pos-command-field")
    field.fill_in with: "ABC"
    field.send_keys :left, :left, :delete
    assert_equal "AC", field.value

    sku = @variant.sku.to_s
    hyphenated = sku.length > 3 ? "#{sku[0..2]}-#{sku[3..]}" : "#{sku}-"
    field.fill_in with: hyphenated
    field.send_keys :enter
    assert_text "Example Book"
    field = find("#pos-command-field")
    field.fill_in with: "978-0-14"
    assert_equal "978-0-14", field.value
    assert_text "Example Book"
    field.fill_in with: ""
    field.send_keys :f8
    assert_no_text "Example Book"
  end

  test "empty basket disables cancel" do
    open_register
    assert_button "Cancel (F9)", disabled: true
  end

  test "quantity mode prefills and invalid quantity stays in quantity" do
    open_register
    add_current_sku
    click_on "Quantity (*)"
    assert_text "QUANTITY"
    field = find("#pos-command-field")
    assert_equal "1", field.value
    field.fill_in with: "0"
    field.send_keys :enter
    assert_text "QUANTITY"
    assert_text "quantity must be positive"
    assert_equal "0", find("#pos-command-field").value
  end

  test "insufficient cash stays in tender and escape returns to sale entry" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    assert_text "CASH TENDER"
    field = find("#pos-command-field")
    field.fill_in with: "0.01"
    field.send_keys :enter
    assert_text "CASH TENDER"
    assert_text "less than amount due"
    send_keys :escape
    assert_text "SALE ENTRY"
    assert_text "Scan or identifier"
  end

  test "cancel overlay ignores enter and confirms on f9" do
    open_register
    add_current_sku
    send_keys :f9
    assert_text "Cancel this sale?"
    send_keys :enter
    assert_text "Cancel this sale?"
    assert_text "Example Book"
    send_keys :f9
    assert_text "SALE ENTRY"
    assert_no_text "Example Book"
  end

  test "completed receipt enter is a no-op and workspace without a working sale returns to enter" do
    open_register
    add_current_sku
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Sale complete", wait: 10
    send_keys :enter
    assert_text "Sale complete"
    visit pos_register_workspace_path
    assert_text "Open register"
  end

  test "unknown identifier feedback does not move the command field" do
    open_register
    field = find("#pos-command-field")
    before = command_field_top
    field.fill_in with: "0000000000000"
    field.send_keys :enter
    assert_css "#pos_feedback"
    assert_equal before, command_field_top
  end

  test "refresh restores the in_flight operation id and return to sale clears the tender" do
    open_register
    add_current_sku
    transaction = PosTransaction.working.find_by!(register: @register)
    Pos::TenderCash.call(
      transaction: transaction,
      actor: @actor,
      expected_lock_version: transaction.lock_version,
      amount_presented_cents: 2500
    )
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

    visit pos_register_workspace_path
    assert_text "Completion is still processing"
    assert_selector "input[name='completion_operation_id'][value='#{operation_id}']", visible: false
    visit pos_register_workspace_path
    assert_selector "input[name='completion_operation_id'][value='#{operation_id}']", visible: false

    click_on "Return to sale"
    assert_text "SALE ENTRY"
    assert_text "Example Book"
    assert_no_text "CHANGE"
    assert_equal 0, transaction.reload.pos_tenders.count
  end

  test "retry complete after inventory failure does not re-tender" do
    open_register
    add_current_sku
    shrink_current_sku(5)
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "50.00"
    field.send_keys :enter
    assert_text "Retry complete", wait: 10
    transaction = PosTransaction.working.find_by!(register: @register)
    assert_equal 1, transaction.pos_tenders.count

    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 5)
    click_on "Retry complete"
    assert_text "Sale complete", wait: 10
    completed = PosTransaction.completed.find_by!(register: @register)
    assert_equal 1, completed.pos_tenders.count
    assert_equal 1, OutboxMessage.where(event_type: "pos.transaction_completed").count
  end

  private

  def sign_in_admin
    visit new_session_path
    fill_in "session_username", with: "admin"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
  end

  def open_register
    sign_in_admin
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
  end

  def add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_text "Example Book"
  end

  def command_field_top
    page.evaluate_script("document.getElementById('pos-command-field').getBoundingClientRect().top")
  end

  def shrink_current_sku(quantity)
    Inventory::AdjustmentReasons.seed!
    Inventory::PostAdjustment.call(
      store: @store,
      product_variant: @variant,
      adjustment_reason: AdjustmentReason.find_by!(code: "shrinkage"),
      quantity_delta: -quantity,
      actor: @actor,
      source_id: SecureRandom.uuid_v7,
      idempotency_key: SecureRandom.uuid_v7
    )
  end
end
