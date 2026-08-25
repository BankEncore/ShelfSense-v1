# frozen_string_literal: true

require "application_system_test_case"

class AdminUds5CompositionPrototypeSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "fixture keeps long titles, omitted slots, and primitives at 320 and zoom" do
    visit admin_uds5_composition_prototype_path
    assert_selector ".uds-5-composition-prototype"
    assert_selector "[data-uds5-header=full] .type-page-title", text: /Left Hand of Darkness/
    assert_no_selector "[data-uds5-header=minimal] .page-header__subtitle"
    assert_no_selector "[data-uds5-header=minimal] .page-header__status"
    assert_selector ".metric-strip"
    assert_selector ".admin-form-footer"
    assert_selector ".data-table .cell-primary"

    with_viewport(width: 320, height: 568) do
      assert_selector "[data-uds5-header=full] .type-page-title", text: /Left Hand of Darkness/
      assert_selector ".metric-strip__value", text: "$18.99"
      refute title_requires_horizontal_scroll?, "page title must wrap at 320px"
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      assert_selector "[data-uds5-header=full] .type-page-title", text: /Left Hand of Darkness/
      assert_selector ".admin-form-footer", text: "Save changes"
    end

    with_viewport(width: 1280, height: 720, zoom: 4) do
      assert_selector "[data-uds5-header=full] .type-page-title", text: /Left Hand of Darkness/
    end

    assert_forced_colors_smoke(surface: "uds5-composition-prototype")
  end

  test "production products page does not render the composition fixture" do
    visit admin_products_path
    assert_selector ".page-header__title", text: "Products"
    assert_no_selector ".uds-5-composition-prototype"
  end

  private

  def title_requires_horizontal_scroll?
    page.evaluate_script("document.querySelector('[data-uds5-header=full] .page-header__title').scrollWidth > document.querySelector('[data-uds5-header=full] .page-header__title').clientWidth + 1")
  end
end
