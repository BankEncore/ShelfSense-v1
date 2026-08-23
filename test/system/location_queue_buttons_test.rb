# frozen_string_literal: true

require "application_system_test_case"

class LocationQueueButtonsTest < ApplicationSystemTestCase
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "lq_#{SecureRandom.hex(3)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "Locate Me Book")
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1, unit_cost_cents: 500)
    @customer = Customer.create!(display_name: "Queue Reader", phone: "555-0111")
    @customer_request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
  end

  test "select opens panel without relying on Stimulus-only buttons" do
    sign_in_and_visit_queue
    assert_no_selector ".location-action-panel:not([hidden])"

    page.execute_script(<<~JS)
      document.querySelectorAll("[data-action*='location-queue']").forEach((el) => el.removeAttribute("data-action"))
    JS

    click_link "Select"
    assert_selector ".location-action-panel:not([hidden])", wait: 5
    assert_text "Physical confirmation required"

    click_link "Not located"
    assert_field "notes", wait: 5

    click_link "Close Esc"
    assert_no_selector ".location-action-panel:not([hidden])", wait: 5

    click_link "Select"
    check "I physically located one copy of this title."
    click_button "Reserve for Queue Reader"
    assert_text "located and reserved", wait: 5
  end

  test "keyboard navigation opens and closes panel with focus on queue row" do
    sign_in_and_visit_queue
    row = find("tr.is-selected")
    row.send_keys :enter
    assert_selector ".location-action-panel:not([hidden])"

    send_keys :escape
    assert_no_selector ".location-action-panel:not([hidden])"
    assert_equal row, page.evaluate_script("document.activeElement.closest('tr')")
  end

  test "dirty panel close requires abandonment confirmation with location copy" do
    sign_in_and_visit_queue
    find("tr.is-selected").send_keys :enter
    click_link "Not located"
    fill_in "Notes (optional)", with: "Shelf was empty"

    dismiss_confirm("Discard this location entry?") do
      click_link "Close Esc"
    end
    assert_selector ".location-action-panel:not([hidden])"
    assert_field "Notes (optional)", with: "Shelf was empty"

    accept_confirm("Discard this location entry?") do
      click_link "Close Esc"
    end
    assert_no_selector ".location-action-panel:not([hidden])"
  end

  test "successful locate focuses first remaining queue row after redirect" do
    second_customer = Customer.create!(display_name: "Next Reader", phone: "555-0112")
    Customers::CreateRequest.call(
      store: @store,
      customer: second_customer,
      product_variant: @variant,
      actor: @actor
    )

    sign_in_and_visit_queue
    find("tr.is-selected").send_keys :enter
    check "I physically located one copy of this title."
    click_button "Reserve for Queue Reader"
    assert_text "located and reserved", wait: 5

    assert_selector "tr.is-selected", text: "Next Reader"
    assert page.evaluate_script("document.activeElement.closest('tr')?.classList.contains('is-selected')")
  end

  test "final locate focuses empty state heading" do
    sign_in_and_visit_queue
    find("tr.is-selected").send_keys :enter
    check "I physically located one copy of this title."
    click_button "Reserve for Queue Reader"
    assert_text "Location work is caught up", wait: 5
    assert_equal "location-empty-heading", page.evaluate_script("document.activeElement.id")
  end

  test "location workspace does not show draft PO shortcut controls" do
    sign_in_and_visit_queue
    assert_no_button "Focus lookup /"
    assert_button "Shortcut help"
  end

  private

  def sign_in_and_visit_queue
    visit new_session_path
    fill_in "session_username", with: @actor.username
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
    visit ops_location_path
  end
end
