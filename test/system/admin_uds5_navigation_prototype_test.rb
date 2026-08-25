# frozen_string_literal: true

require "application_system_test_case"

class AdminUds5NavigationPrototypeSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "compact variants are shorter than expanded and keep destinations at 320 and zoom" do
    heights = {}

    %w[expanded disclosures area_row].each do |variant|
      visit admin_uds5_navigation_prototype_path(variant: variant, as_controller: "admin/products")
      assert_selector ".uds-5-nav-prototype--#{variant}"
      with_viewport(width: 1440, height: 900) do
        heights[variant] = prototype_height
      end
    end

    assert heights["disclosures"] < heights["expanded"],
      "disclosures (#{heights['disclosures']}) must be shorter than expanded (#{heights['expanded']}) at 1440×900"
    assert heights["area_row"] < heights["expanded"],
      "area_row (#{heights['area_row']}) must be shorter than expanded (#{heights['expanded']}) at 1440×900"

    visit admin_uds5_navigation_prototype_path(variant: "disclosures", as_controller: "admin/products")
    with_viewport(width: 320, height: 568) do
      assert_selector ".uds-5-nav-prototype a.uds-5-nav-prototype__destination", text: "Products", visible: :all
      assert_selector ".uds-5-nav-prototype a.uds-5-nav-prototype__destination", text: "Users", visible: :all
      refute prototype_requires_horizontal_scroll?, "prototype must not require two-dimensional scrolling at 320px"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector ".uds-5-nav-prototype a.uds-5-nav-prototype__destination", text: "Products", visible: :all
      assert_selector ".uds-5-nav-prototype a.uds-5-nav-prototype__destination", text: "Audit events", visible: :all
    end

    with_viewport(width: 1280, height: 720, zoom: 4) do
      assert_selector ".uds-5-nav-prototype a.uds-5-nav-prototype__destination", text: "Products", visible: :all
    end
  end

  test "disclosure summaries open with keyboard and reveal destinations" do
    visit admin_uds5_navigation_prototype_path(variant: "disclosures", as_controller: "admin/products")
    summary = find("summary[data-uds5-group='security']")
    summary.send_keys :return
    assert_selector ".uds-5-nav-prototype details[open] a.uds-5-nav-prototype__destination", text: "Users"
  end

  test "production products header remains the expanded grouped catalog" do
    visit admin_products_path
    assert_selector ".app-nav--grouped"
    assert_no_selector ".uds-5-nav-prototype"
    with_viewport(width: 1440, height: 900) do
      assert page.evaluate_script("document.querySelector('.app-nav--grouped').getBoundingClientRect().height") > 0
    end
  end

  private

  def prototype_height
    page.evaluate_script("document.querySelector('.uds-5-nav-prototype').getBoundingClientRect().height")
  end

  def prototype_requires_horizontal_scroll?
    page.evaluate_script("document.querySelector('.uds-5-nav-prototype').scrollWidth > document.querySelector('.uds-5-nav-prototype').clientWidth + 1")
  end
end
