# frozen_string_literal: true

require "application_system_test_case"

class AdminCustomersCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @customer = Customer.create!(
      display_name: "Layout Customer",
      email: "layout.customer@example.com",
      phone: "555-010-2000"
    )
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "index show new and edit remain usable at 320 and zoom" do
    visit admin_customers_path
    assert_selector ".page-header__title", text: "Customers"
    assert_selector "form.filters.surface.customer-filters"
    assert_link "New customer"
    assert_link "Layout Customer"

    visit admin_customer_path(@customer)
    assert_selector ".page-header__title", text: "Layout Customer"
    assert_link "Edit"
    assert_selector "h2", text: "Merge into another customer"
    assert_selector "h2", text: "Stored value"
    assert_selector "h2", text: "Associated gift cards"
    assert_selector "h2", text: "Recent requests"

    visit new_admin_customer_path
    assert_selector ".page-header__title", text: "New customer"
    assert_link "Cancel"
    assert_button "Create Customer"

    visit edit_admin_customer_path(@customer)
    assert_selector ".page-header__title", text: "Edit customer"
    assert_link "Cancel"
    assert_button "Save Changes"

    with_viewport(width: 320, height: 568) do
      visit admin_customers_path
      assert_selector ".page-header__title", text: "Customers"
      assert_link "New customer"
      assert_layout_usable(
        surface: "customers-index-320",
        scroll_selector: ".table-scroll"
      )

      visit admin_customer_path(@customer)
      assert_selector ".page-header__title", text: "Layout Customer"
      assert_link "Edit"
      assert_selector "h2", text: "Merge into another customer"
      assert_selector "h2", text: "Stored value"
      assert_selector "h2", text: "Associated gift cards"
      assert_selector "h2", text: "Recent requests"
      assert_layout_usable(surface: "customers-show-320")

      visit new_admin_customer_path
      assert_selector ".page-header__title", text: "New customer"
      assert_link "Cancel"
      assert_button "Create Customer"
      assert_layout_usable(surface: "customers-new-320")

      visit edit_admin_customer_path(@customer)
      assert_selector ".page-header__title", text: "Edit customer"
      assert_link "Cancel"
      assert_button "Save Changes"
      assert_layout_usable(surface: "customers-edit-320")
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      visit admin_customers_path
      assert_selector ".page-header__title", text: "Customers"
      assert_link "New customer"
      assert_layout_usable(
        surface: "customers-index-200-percent",
        scroll_selector: ".table-scroll"
      )

      visit admin_customer_path(@customer)
      assert_selector ".page-header__title", text: "Layout Customer"
      assert_link "Edit"
      assert_selector "h2", text: "Merge into another customer"
      assert_selector "h2", text: "Stored value"
      assert_selector "h2", text: "Associated gift cards"
      assert_selector "h2", text: "Recent requests"
      assert_layout_usable(surface: "customers-show-200-percent")

      visit new_admin_customer_path
      assert_selector ".page-header__title", text: "New customer"
      assert_link "Cancel"
      assert_button "Create Customer"
      assert_layout_usable(surface: "customers-new-200-percent")

      visit edit_admin_customer_path(@customer)
      assert_selector ".page-header__title", text: "Edit customer"
      assert_link "Cancel"
      assert_button "Save Changes"
      assert_layout_usable(surface: "customers-edit-200-percent")
    end
  end

  test "standard migrated width matches unmigrated users at a wide viewport" do
    with_viewport(width: 1920, height: 1080) do
      visit admin_users_path
      assert_selector "h1", text: "Users"
      unmigrated_width = app_content_used_width
      root_px = page.evaluate_script("parseFloat(getComputedStyle(document.documentElement).fontSize)")
      max_standard = (72 * root_px) + 1

      visit admin_adjustment_reasons_path
      assert_selector ".page-header__title", text: "Adjustment reasons"
      reasons_width = app_content_used_width

      visit admin_customers_path
      assert_selector ".page-header__title", text: "Customers"
      customers_width = app_content_used_width

      assert_in_delta unmigrated_width, reasons_width, 1.0
      assert_in_delta unmigrated_width, customers_width, 1.0
      assert_operator customers_width, :<=, max_standard
      assert_operator unmigrated_width, :<=, max_standard
    end
  end

  private

  def app_content_used_width
    page.evaluate_script(<<~JS)
      document.querySelector("main.app-content").getBoundingClientRect().width
    JS
  end
end
