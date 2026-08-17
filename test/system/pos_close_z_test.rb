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
    assert_button "Close register"
    click_on "Close register"
    assert_text "Closing Cash count"
    assert_no_text "Expected"
    assert_no_text "Opening float"
    assert_no_text "$100.00"
    assert_no_text "Variance"

    field = find("#closing_count")
    field.fill_in with: "0.00"
    field.send_keys :enter

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
    assert_no_button "Close register"
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "25.00"
    field.send_keys :enter
    send_keys :enter

    assert_text "Sale complete", wait: 10
    assert_button "Print receipt"
    assert_text "New sale"
    assert_text "Close register"
    assert_selector ".pos-receipt__print-header", visible: :all, text: /Store: 001\s+Reg: 01\s+Trans:/
    transaction = PosTransaction.completed.find_by!(register: @register)
    send_keys :enter
    assert_text "Sale complete"
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
    assert_no_button "Close register"
    find("#pos-command-field").send_keys :escape
    click_on "Tender (+)"
    assert_text "CASH TENDER"
    assert_no_button "Close register"
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
    assert_text "SALE ENTRY"
  end

  def add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_text "Example Book"
  end
end
