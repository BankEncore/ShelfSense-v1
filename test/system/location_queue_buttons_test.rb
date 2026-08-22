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
    Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @actor
    )
  end

  test "select opens panel without relying on Stimulus-only buttons" do
    visit new_session_path
    fill_in "session_username", with: @actor.username
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"

    visit ops_location_path
    assert_no_selector ".location-action-panel:not([hidden])"

    # Disable Stimulus actions to prove progressive enhancement via real links.
    page.execute_script(<<~JS)
      document.querySelectorAll("[data-action*='location-queue']").forEach((el) => el.removeAttribute("data-action"))
    JS

    click_link "Select"
    assert_selector ".location-action-panel:not([hidden])", wait: 5
    assert_text "Physical confirmation required"

    click_link "Not located"
    assert_field "notes", wait: 5

    click_link "Close"
    assert_no_selector ".location-action-panel:not([hidden])", wait: 5

    click_link "Select"
    check "I physically located one copy of this title."
    click_button "Reserve for Queue Reader"
    assert_text "located and reserved", wait: 5
  end
end
