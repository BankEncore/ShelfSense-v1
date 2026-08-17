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
    sign_in_admin
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"

    assert_text "SALE ENTRY"
    field = find("#pos-command-field")
    field.fill_in with: @variant.sku
    field.send_keys :enter
    assert_text "Example Book"
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

    assert_text "Sale complete", wait: 10
    assert_text "New sale"
    send_keys :enter
    assert_text "Sale complete"
    click_on "New sale"
    assert_text "SALE ENTRY"
    assert_no_text "Example Book"
  end

  test "empty basket disables cancel" do
    sign_in_admin
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"

    assert_text "SALE ENTRY"
    assert_button "Cancel (F9)", disabled: true
  end

  private

  def sign_in_admin
    visit new_session_path
    fill_in "session_username", with: "admin"
    fill_in "session_password", with: "correct-horse-battery"
    click_button "Sign in"
    assert_text "Signed in successfully"
  end
end
