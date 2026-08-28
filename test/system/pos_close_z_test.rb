# frozen_string_literal: true

require "application_system_test_case"

class PosCloseZTest < ApplicationSystemTestCase
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

  test "empty sale entry can close with a blind zero count and finalize z" do
    open_register(opening_float: "100.00")
    assert_button "Close Session"
    click_on "Close Session"
    assert_text "Closing Cash count"
    assert_no_text "Expected"
    assert_no_text "Opening float"
    assert_no_text "$100.00"

    field = find("#closing_count")
    field.fill_in with: "0.00"
    select "Short count", from: "variance_reason_code"
    fill_in "Over/short note", with: "Blind zero count"
    click_on "Close session"

    assert_text "Session closed"
    assert_text "Expected closing Cash"
    assert_text "$100.00"
    assert_text "Counted Cash"
    click_on "Finalize Z"
    assert_text "Z report"
    assert_text "Store 001"
    assert_text "Register 01"
    assert_text "Opening floats total"
    period = PosReportingPeriod.finalized.find_by!(register: @register)
    assert period.finalized?
    assert_equal 0, period.finalized_transaction_count
  end

  test "completed sale can print and close the register" do
    open_register(opening_float: "100.00")
    add_current_sku
    assert_no_button "Close Session"
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "25.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Transaction complete", wait: 10
    assert_button "Print receipt"
    assert_text "New transaction"
    assert_text "Close register"
    assert_selector ".pos-receipt__print-header", visible: :all, text: /Store: 001\s+Reg: 01\s+Trans:/
    transaction = PosTransaction.completed.find_by!(register: @register)
    send_keys :enter
    assert_text "Transaction complete"
    assert transaction.reload.completed?

    click_on "Close register"
    assert_text "Closing Cash count"
    fill_in "Closing Cash count", with: "120.99"
    click_on "Close session"
    assert_text "Session closed"
    assert_text "Leave period open"
    click_on "Leave period open"
    assert_button "Finalize Z"
    assert_button "Open session"
  end

  test "quantity and tender do not expose close register" do
    open_register
    add_current_sku
    click_on "Quantity (*)"
    assert_text "QUANTITY"
    assert_no_button "Close Session"
    find("#pos-command-field").send_keys :escape
    click_on "Tender (+)"
    assert_text "CASH TENDER"
    assert_no_button "Close Session"
  end

  test "cashier can complete the phase 5 open sell print close and z path" do
    sign_in_admin
    visit pos_register_enter_path(register_id: @register.id)
    assert_text "Business date"
    fill_in "Opening float", with: "100.00"
    click_on "Open register"
    assert_text "SALE ENTRY"

    add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tr.is-selected[data-quantity='2']"

    click_on "Quantity (*)"
    assert_text "QUANTITY"
    field = find("#pos-command-field")
    field.fill_in with: "1"
    field.send_keys :enter
    assert_text "SALE ENTRY"
    assert_selector "tr.is-selected[data-quantity='1']"

    click_on "Tender (+)"
    assert_text "CASH TENDER"
    field = find("#pos-command-field")
    field.fill_in with: "25.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Transaction complete", wait: 10
    assert_text "Change"
    assert_button "Print receipt"
    assert_selector ".pos-receipt__print-header", visible: :all, text: /Store: 001\s+Reg: 01\s+Trans:/
    transaction = PosTransaction.completed.find_by!(register: @register)
    assert transaction.completed?

    click_on "Close register"
    assert_text "Closing Cash count"
    assert_no_text "Expected"
    assert_no_text "Opening float"
    assert_no_text "$100.00"
    session_record = PosSession.open.find_by!(register: @register)
    expected = session_record.opening_float_cents + Pos::SessionTotals.for(session_record).cash_tender_cents
    fill_in "Closing Cash count", with: format("%<dollars>d.%<cents>02d", dollars: expected / 100, cents: expected % 100)
    click_on "Close session"

    assert_text "Session closed"
    session_record.reload
    assert session_record.closed?
    assert_equal expected, session_record.closing_expected_cash_cents
    assert_equal expected, session_record.closing_count_cents
    assert_equal 0, session_record.closing_variance_cents
    assert_text "Expected closing Cash"
    assert_text "Variance"

    click_on "Finalize Z"
    assert_text "Z report"
    period = PosReportingPeriod.finalized.find_by!(register: @register)
    assert period.finalized?
    assert_equal session_record.closing_expected_cash_cents, period.finalized_closing_expected_cash_cents_sum
    assert_equal session_record.closing_count_cents, period.finalized_closing_count_cents_sum
    assert_equal 0, period.finalized_closing_variance_cents_sum
    assert_no_button "Finalize Z"
  end

  private

  def sign_in_admin
    visit new_session_path
    fill_in "session_username", with: "admin"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
  end

  def open_register(opening_float: "0.00")
    sign_in_admin
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: opening_float
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
  end

  def add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tbody tr.is-selected", text: "Example Book", wait: 10
  end
end
