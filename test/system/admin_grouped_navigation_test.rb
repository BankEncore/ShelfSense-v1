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
      # 320 CSS px is also the WCAG 1.4.10 400% reflow width of a 1280 layout.
      assert_selector ".app-nav__current-destination a", text: "Products"
      assert_selector ".app-nav__areas > summary", text: /areas/i
      assert_selector ".app-nav__area-row a", text: "Products", visible: :hidden
      assert_selector ".app-nav__areas a", text: "Users", visible: :all
      refute nav_requires_horizontal_scroll?, "compact nav must not require two-dimensional scrolling at 320px / 400% equivalent"
      refute header_obscures_page_content?, "header must leave page content visible at 320px / 400% equivalent"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector ".app-nav__area-row a", text: "Products"
      assert_selector ".app-nav__wide-groups a", text: "Audit events", visible: :all
    end

    with_viewport(width: 1280, height: 720, zoom: 4) do
      assert_selector ".app-nav__area-row a", text: "Products"
      refute nav_requires_horizontal_scroll?, "compact nav must not require two-dimensional scrolling at 400% CSS zoom"
    end
  end

  test "disclosure summaries open with keyboard and reveal destinations" do
    visit admin_products_path
    summary = find(".app-nav__wide-groups summary[data-nav-group='security']")
    summary.send_keys :return
    assert_selector ".app-nav__wide-groups details[open] a", text: "Users"
  end

  test "narrow Areas disclosure opens with keyboard and reveals destinations" do
    visit admin_products_path

    with_viewport(width: 320, height: 568) do
      find(".app-nav__areas > summary").send_keys :return
      find(".app-nav__areas summary[data-nav-group='security']").send_keys :return
      assert_selector ".app-nav__areas details[open] a", text: "Users"
    end
  end

  private

  def nav_requires_horizontal_scroll?
    page.evaluate_script("document.querySelector('.app-nav--grouped').scrollWidth > document.querySelector('.app-nav--grouped').clientWidth + 1")
  end

  def header_obscures_page_content?
    page.evaluate_script(<<~JS)
      (function() {
        var header = document.querySelector(".app-header");
        var content = document.querySelector(".app-content");
        if (!header || !content) return true;
        var headerBox = header.getBoundingClientRect();
        var contentBox = content.getBoundingClientRect();
        return headerBox.height >= window.innerHeight || contentBox.top >= window.innerHeight;
      })()
    JS
  end
end
