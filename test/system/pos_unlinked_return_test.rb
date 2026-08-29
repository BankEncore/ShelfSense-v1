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
    assert_text "Unlinked return"

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
    click_on "Add Unlinked Return"

    assert_text "RETURN", wait: 10
    assert_text "Unlinked return"
    assert_text "Refund remaining"
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
    click_on "Add Unlinked Return"
    assert_text "Unlinked return", wait: 10

    click_on "Refund (+)"
    field = find("#pos-command-field")
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    assert unit.reload.on_hand?
  end

  test "shared lookup opens product picker without Escape then posts the return" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Beta Shared Return")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 3)
    @variant.product.update!(lookup_code: "UNL-SHARED")
    other.product.update!(lookup_code: "UNL-SHARED")

    open_register_as("admin")
    open_unlinked_overlay

    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: "unl-shared"
    identifier.send_keys :enter

    assert_selector "#pos_product_overlay", visible: true, wait: 5
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_selector "#pos_product_overlay li", count: 2
    assert page.evaluate_script("document.activeElement === document.querySelector('#pos_product_overlay li.is-selected')")

    send_keys :enter

    assert_no_selector "#pos_product_overlay", visible: true, wait: 5
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_text "Current price", wait: 5
    assert_text(/Example Book|Beta Shared Return/)
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count

    select "Defective", from: "Return reason"
    click_on "Add Unlinked Return"

    assert_text "RETURN", wait: 10
    assert_text "Unlinked return"
    assert_equal 1, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count
  end

  test "Escape on stacked product picker leaves Return without receipt open" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Gamma Shared Return")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 2)
    @variant.product.update!(lookup_code: "UNL-ESC")
    other.product.update!(lookup_code: "UNL-ESC")

    open_register_as("admin")
    open_unlinked_overlay

    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: "unl-esc"
    identifier.send_keys :enter

    assert_selector "#pos_product_overlay", visible: true, wait: 5
    send_keys :escape

    assert_no_selector "#pos_product_overlay", visible: true
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_field "pos-unlinked-identifier"
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count
  end

  test "rejected unlinked approver credentials keep nested overlays and clear password" do
    open_register_as("clerk_sys65c")
    open_unlinked_overlay
    assert_selector "#pos_return_chooser", visible: :all
    assert page.evaluate_script("document.querySelector('#pos_return_chooser').inert === true")

    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: @variant.sku
    identifier.send_keys :enter
    assert_text "Example Book", wait: 5
    fill_in "Return unit price", with: "18.00"
    select "Defective", from: "Return reason"
    find("#pos-unlinked-approver-username", visible: true).fill_in with: "mgr_sys65c"
    password = find("#pos-unlinked-approver-password", visible: :all)
    scroll_to password
    password.fill_in with: "wrong-password"
    click_on "Add Unlinked Return"

    assert_selector "#pos-unlinked-feedback", text: /approver/i, wait: 10
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_selector "#pos_return_chooser", visible: :all
    assert page.evaluate_script("document.querySelector('#pos_return_chooser').inert === true")
    assert_equal "18.00", find("#pos-unlinked-price").value
    assert_equal "defective", find("#pos-unlinked-reason").value
    assert_equal "mgr_sys65c", find("#pos-unlinked-approver-username").value
    assert_equal "", find("#pos-unlinked-approver-password", visible: :all).value
  end

  test "pointer Back on nested product picker restores unlinked overlay" do
    other = pos_sellable_variant(actor: @actor, tax_class: @tax, name: "Delta Shared Return")
    open_quantity_stock(store: @store, variant: other, actor: @actor, quantity: 2)
    @variant.product.update!(lookup_code: "UNL-BACK")
    other.product.update!(lookup_code: "UNL-BACK")

    open_register_as("admin")
    open_unlinked_overlay
    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: "unl-back"
    identifier.send_keys :enter
    assert_selector "#pos_product_overlay", visible: true, wait: 5
    click_on "Cancel (Esc)"
    assert_no_selector "#pos_product_overlay", visible: true
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_field "pos-unlinked-identifier"
  end

  test "unlinked variant picker Back label returns to item lookup" do
    ProductVariants::Create.call(
      product: @variant.product,
      attributes: {
        variant_type: "standard",
        status: "active",
        merchandise_class_id: @variant.merchandise_class_id,
        regular_price_cents: 1500
      },
      actor: @actor
    )
    open_quantity_stock(store: @store, variant: @variant.product.product_variants.order(:created_at).last, actor: @actor, quantity: 2)

    open_register_as("admin")
    open_unlinked_overlay
    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: @variant.product.primary_identifier
    identifier.send_keys :enter
    assert_selector "#pos_variant_overlay", visible: true, wait: 5
    assert_button "Back to Item Lookup"
    click_on "Back to Item Lookup"
    assert_no_selector "#pos_variant_overlay", visible: true
    assert_selector "#pos_unlinked_overlay", visible: true
    assert_field "pos-unlinked-identifier"
  end

  private

  def open_register_as(username)
    visit new_session_path
    fill_in "session_username", with: username
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "500.00"
    click_on "Open register"
    assert_text "SALE ENTRY", wait: 10
  end

  def open_unlinked_overlay
    click_on "Return (-)"
    send_keys :arrow_down
    send_keys :enter
    assert_selector "#pos_unlinked_overlay", visible: true
  end
end
