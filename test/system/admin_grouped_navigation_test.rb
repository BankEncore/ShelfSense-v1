# frozen_string_literal: true

require "application_system_test_case"

class AdminGroupedNavigationSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "compact area row keeps destinations at 320 and zoom" do
    visit admin_products_path
    assert_selector ".app-nav--grouped"
    assert_selector ".app-nav__area-row a", text: "Products"
    assert_no_selector ".uds-5-nav-prototype"
    refute_selector ".app-nav__area-row a", text: "Users"

    with_viewport(width: 320, height: 568) do
      assert_selector ".app-nav__area-row a", text: "Products"
      assert_selector ".app-nav--grouped a", text: "Users", visible: :all
      refute nav_requires_horizontal_scroll?, "compact nav must not require two-dimensional scrolling at 320px"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector ".app-nav__area-row a", text: "Products"
      assert_selector ".app-nav--grouped a", text: "Audit events", visible: :all
    end

    with_viewport(width: 1280, height: 720, zoom: 4) do
      assert_selector ".app-nav__area-row a", text: "Products"
    end
  end

  test "disclosure summaries open with keyboard and reveal destinations" do
    visit admin_products_path
    summary = find("summary[data-nav-group='security']")
    summary.send_keys :return
    assert_selector ".app-nav--grouped details[open] a", text: "Users"
  end

  private

  def nav_requires_horizontal_scroll?
    page.evaluate_script("document.querySelector('.app-nav--grouped').scrollWidth > document.querySelector('.app-nav--grouped').clientWidth + 1")
  end
end
