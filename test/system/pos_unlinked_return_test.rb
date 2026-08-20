# frozen_string_literal: true

require "application_system_test_case"

class PosUnlinkedReturnTest < ApplicationSystemTestCase
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
    @associate = pos_transacting_user(store: @store, assigned_by: @actor, username: "clerk_sys65c")
    pos_store_manager(store: @store, assigned_by: @actor, username: "mgr_sys65c")
  end

  test "associate return without receipt needs manager credentials then cash refunds" do
    open_register_as("clerk_sys65c")
    assert_no_button "Return without receipt"
    open_unlinked_overlay
    assert_text "Return without receipt"

    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: @variant.sku
    identifier.send_keys :enter
    assert_text "Example Book", wait: 5
    assert_text "Current price"
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count

    fill_in "Return unit price", with: "18.00"
    select "Defective", from: "Return reason"
    find("#pos-unlinked-approver-username", visible: true).fill_in with: "mgr_sys65c"
    password = find("#pos-unlinked-approver-password", visible: :all)
    scroll_to password
    password.fill_in with: "correct-horse-battery"
    click_on "Add return"

    assert_text "RETURN", wait: 10
    assert_text "Unlinked return"
    assert_text "Refund due"
    refute_text "Override"

    click_on "Refund (+)"
    assert_text "REFUND"
    field = find("#pos-command-field")
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    assert_text "Cash refund"
    assert_text "Unlinked return"
    assert_text "Reference"
  end

  test "cashier returns a known removed used unit without a receipt" do
    used_variant, unit = pos_on_hand_unit(store: @store, actor: @actor, tax_class: @tax)
    open_register_as("admin")
    field = find("#pos-command-field")
    field.fill_in with: unit.unit_identifier
    field.send_keys :enter
    assert_text used_variant.product.name
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "20.00"
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    assert unit.reload.removed?

    click_on "New transaction"
    assert_text "SALE ENTRY"
    open_unlinked_overlay
    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: unit.unit_identifier
    identifier.send_keys :enter
    assert_text used_variant.product.name, wait: 5
    assert_no_selector "#pos-unlinked-quantity", visible: true
    select "Changed mind", from: "Return reason"
    click_on "Add return"
    assert_text "Unlinked return", wait: 10

    click_on "Refund (+)"
    field = find("#pos-command-field")
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    assert unit.reload.on_hand?
  end

  private

  def open_register_as(username)
    visit new_session_path
    fill_in "session_username", with: username
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
  end

  def open_unlinked_overlay
    click_on "Return (-)"
    send_keys :arrow_down
    send_keys :enter
    assert_selector "#pos_unlinked_overlay", visible: true
  end
end
