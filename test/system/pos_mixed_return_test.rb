# frozen_string_literal: true

require "application_system_test_case"

class PosMixedReturnTest < ApplicationSystemTestCase
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
    @thirty, @twenty = priced_variants(3000, 2000)
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
  end

  test "sale then unlinked return tenders cash for the positive net" do
    open_register
    add_sku(@thirty.sku)
    add_unlinked_return(@twenty.sku, price: "20.00")
    assert_text "Amount due"
    click_on "Tender (+)"
    field = find("#pos-command-field")
    field.fill_in with: "10.00"
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    completed = PosTransaction.completed.find_by!(register: @register)
    assert completed.signed_net_cents.positive?
    assert_text "Unlinked return"
    assert_text "Net"
    click_on "Transactions"
    assert_text format_signed(completed.signed_net_cents)
    click_on completed.transaction_reference
    assert_text "Unlinked return"
    assert_selector ".pos-receipt__reprint", visible: :all, text: "REPRINT"
  end

  test "negative net split refunds cash and card" do
    open_register
    add_sku(@twenty.sku)
    add_unlinked_return(@thirty.sku, price: "30.00")
    assert_text "Refund due"
    click_on "Refund (+)"
    assert_text "REFUND"
    send_keys :f2
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /External Card/
    field = find("#pos-command-field")
    field.fill_in with: "4.00"
    field.send_keys :enter
    field = find("#pos-command-field")
    field.send_keys :f1
    assert_selector "[data-register-workspace-target='fieldLabel']", text: /Refund amount/
    field = find("#pos-command-field")
    field.send_keys :enter
    send_keys :enter
    assert_text "Transaction complete", wait: 10
    assert_text "Cash refund"
    assert_text "External Card refund"
    completed = PosTransaction.completed.find_by!(register: @register)
    assert completed.signed_net_cents.negative?
    assert_equal %w[card cash], completed.pos_tenders.ordered.map(&:behavioral_category)
  end

  test "even exchange completes with plus and no tender rows" do
    open_register
    add_sku(@twenty.sku)
    add_unlinked_return(@twenty.sku, price: "20.00")
    assert_text "Even exchange"
    assert_text "SALE ENTRY"
    assert_no_text "Transaction complete"
    assert_button "Complete (+)"
    click_on "Complete (+)"
    assert_text "Transaction complete", wait: 10
    completed = PosTransaction.completed.find_by!(register: @register)
    assert_equal 0, completed.signed_net_cents
    assert_equal 0, completed.pos_tenders.count
  end

  test "overlay lookup enter escape and return-line keys stay on sale entry" do
    open_register
    click_on "Return (-)"
    send_keys :arrow_down
    send_keys :enter
    assert_text "Return without receipt"
    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: @twenty.sku
    identifier.send_keys :enter
    assert_text "Priced 2000", wait: 5
    assert_equal 0, PosTransaction.working.find_by!(register: @register).pos_transaction_lines.count
    send_keys :escape
    assert_no_selector "#pos_unlinked_overlay", visible: true
    assert_equal "pos-command-field", page.evaluate_script("document.activeElement && document.activeElement.id")

    add_sku(@thirty.sku)
    add_unlinked_return(@twenty.sku, price: "20.00")
    assert_selector "tr.is-selected[data-direction='return']"
    send_keys :f5
    assert_no_selector "#pos_control_overlay", visible: true
    send_keys :f6
    assert_no_selector "#pos_control_overlay", visible: true
    send_keys :f7
    assert_no_selector "#pos_control_overlay", visible: true
    send_keys :f8
    assert_no_selector "tr[data-direction='return']"
    assert_selector "tr[data-direction='sale']"

    send_keys :f9
    assert_selector "#pos_overlay", visible: true
    send_keys :escape
    assert_no_selector "#pos_overlay", visible: true
    assert_text "SALE ENTRY"
    send_keys :f9
    send_keys :f9
    assert_text "SALE ENTRY"
    assert_no_text "Priced 3000"
  end

  private

  def open_register
    visit new_session_path
    fill_in "session_username", with: "admin"
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit pos_register_enter_path(register_id: @register.id)
    fill_in "Opening float", with: "0.00"
    click_on "Open register"
    assert_text "SALE ENTRY"
  end

  def priced_variants(*prices)
    untaxed = tax_class(code: "untaxed_mixed_sys_#{SecureRandom.hex(3)}")
    StoreTaxes::EnsureRules.for_tax_class(untaxed)
    StoreTaxRule.find_by!(store_tax: StoreTax.find_by!(store: @store), tax_class: untaxed).update!(applies: false)
    prices.map.with_index do |cents, index|
      variant = pos_sellable_variant(actor: @actor, tax_class: untaxed, name: "Priced #{cents} #{index}")
      variant.update_columns(regular_price_cents: cents)
      open_quantity_stock(store: @store, variant: variant, actor: @actor, quantity: 20, unit_cost_cents: 100)
      variant
    end
  end

  def add_sku(sku)
    field = find("#pos-command-field")
    field.fill_in with: sku
    field.send_keys :enter
    assert_selector "tr[data-direction='sale']"
  end

  def add_unlinked_return(sku, price:)
    click_on "Return (-)"
    send_keys :arrow_down
    send_keys :enter
    identifier = find("#pos-unlinked-identifier")
    identifier.fill_in with: sku
    identifier.send_keys :enter
    assert_text "Priced", wait: 5
    fill_in "Return unit price", with: price
    select "Changed mind", from: "Return reason"
    click_on "Add return"
    assert_text "Unlinked return", wait: 10
  end

  def format_signed(cents)
    return "$0.00" if cents.to_i.zero?

    prefix = cents.positive? ? "+" : "-"
    absolute = cents.abs
    "#{prefix}$#{absolute / 100}.#{format("%02d", absolute % 100)}"
  end
end
