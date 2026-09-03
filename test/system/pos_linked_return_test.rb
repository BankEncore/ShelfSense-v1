# frozen_string_literal: true

require "application_system_test_case"

class PosLinkedReturnTest < ApplicationSystemTestCase
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

  test "cashier returns from history, refunds cash, and sees session totals" do
    open_register
    add_current_sku
    start_cash_tender_via_plus
    fill_command_field("25.00")
    complete_tender_after_amount
    assert_text "Transaction complete", wait: 10

    sale = PosTransaction.completed.find_by!(register: @register)
    line = sale.pos_transaction_lines.first
    click_on "Transactions"
    click_on sale.transaction_reference
    assert_text "Remaining 1"
    click_on "Return items"
    check "item_#{line.id}_selected"
    select "Changed mind", from: "items_#{line.id}_reason_code"
    click_on "Add to register"

    assert_text "RETURN", wait: 10
    assert_text "Refund remaining"
    start_cash_refund_via_plus
    assert_text "REFUND"
    send_keys :f2
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    send_keys :f1
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /Refund amount/
    complete_tender_after_amount

    assert_text "Transaction complete", wait: 10
    assert_text "Cash refund"
    assert_no_text "Cash presented"
    assert_text "Tax reversal"
    assert_text "Returns total"
    assert_text "Return from #{sale.transaction_reference}"

    returned = PosTransaction.completed.where(register: @register).where.not(id: sale.id).first!
    click_on "Transactions"
    assert_text format_signed(returned.signed_net_cents)
    click_on returned.transaction_reference
    assert_selector ".pos-receipt__print .pos-thermal__status", visible: :all, text: "REPRINT"

    visit pos_completed_transaction_path(returned)
    click_on "Close register"
    fill_in "Closing Cash count", with: "0.00"
    click_on "Close session"
    assert_text "Closed Session Report"
    assert_text "Returns total"
    assert_text "Cash refunds"
    assert_text "Net"
    click_on "Finalize Z…"
    assert_text "Confirmation"
    click_on "Finalize Z"
    assert_text "Z Report"
    assert_text "Returns total"
    assert_text "Cash refunds"
  end

  test "even exchange stays in sale entry until plus confirms complete" do
    open_register
    add_current_sku
    start_cash_tender_via_plus
    fill_command_field("25.00")
    complete_tender_after_amount
    assert_text "Transaction complete", wait: 10

    sale = PosTransaction.completed.find_by!(register: @register)
    line = sale.pos_transaction_lines.first
    click_on "New transaction"
    assert_text "SALE ENTRY"
    choose_register_menu "Transactions & Receipts"
    click_on sale.transaction_reference
    click_on "Return items"
    check "item_#{line.id}_selected"
    select "Changed mind", from: "items_#{line.id}_reason_code"
    click_on "Add to register"
    assert_text "Refund remaining", wait: 10
    assert_selector "tr[data-direction='return']"

    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tr[data-direction='sale']"
    assert_text "SALE ENTRY"
    assert_text "Even exchange"
    assert_no_text "Transaction complete"
    assert_button "Complete (+)"

    click_on "Complete (+)"
    assert_text "Transaction complete", wait: 10
    assert_text "Sales tax"
    assert_text "Tax reversal"
    completed = PosTransaction.completed.where(register: @register).where.not(id: sale.id).first!
    assert_equal 0, completed.signed_net_cents
    assert_equal 0, completed.pos_tenders.count
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
    assert_text "SALE ENTRY", wait: 10
  end

  def add_current_sku
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_selector "tbody tr.is-selected", text: "Example Book", wait: 10
  end

  def format_signed(cents)
    return "$0.00" if cents.to_i.zero?

    prefix = cents.positive? ? "+" : "-"
    absolute = cents.abs
    "#{prefix}$#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end
end
