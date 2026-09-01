# frozen_string_literal: true

require "application_system_test_case"

class AdminAdjustmentReasonsCompositionSystemTest < ApplicationSystemTestCase
  setup do
    @bootstrap = bootstrap!
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
    sign_in_admin(actor: @bootstrap[:administrator])
  end

  test "index show and new remain usable at 320 and zoom" do
    visit admin_adjustment_reasons_path
    assert_selector ".page-header__title", text: "Adjustment reasons"
    assert_link "New reason"

    visit admin_adjustment_reason_path(@opening)
    assert_selector ".page-header__title", text: @opening.name

    visit new_admin_adjustment_reason_path
    assert_selector ".page-header__title", text: "New adjustment reason"
    assert_link "Cancel"

    with_viewport(width: 320, height: 568) do
      visit admin_adjustment_reasons_path
      assert_selector ".page-header__title", text: "Adjustment reasons"
      assert_link "New reason"
      assert_layout_usable(
        surface: "adjustment-reasons-index-320",
        scroll_selector: ".table-scroll"
      )

      visit new_admin_adjustment_reason_path
      assert_selector ".page-header__title", text: "New adjustment reason"
      assert_link "Cancel"
      assert_layout_usable(
        surface: "adjustment-reasons-new-320"
      )
    end

    with_viewport(width: 1280, height: 720, zoom: 2) do
      visit admin_adjustment_reasons_path
      assert_selector ".page-header__title", text: "Adjustment reasons"
      assert_link "New reason"
      assert_layout_usable(
        surface: "adjustment-reasons-index-200-percent",
        scroll_selector: ".table-scroll"
      )

      visit new_admin_adjustment_reason_path
      assert_selector ".page-header__title", text: "New adjustment reason"
      assert_link "Cancel"
      assert_layout_usable(
        surface: "adjustment-reasons-new-200-percent"
      )
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
      standard_width = app_content_used_width

      assert_in_delta unmigrated_width, standard_width, 1.0
      assert_operator standard_width, :<=, max_standard
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
