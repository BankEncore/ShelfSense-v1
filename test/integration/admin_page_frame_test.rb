# frozen_string_literal: true

require "test_helper"

class AdminPageFrameTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @opening = AdjustmentReason.find_by!(code: "opening_inventory")
    @reversal = AdjustmentReason.find_by!(code: "reversal")
    @custom = AdjustmentReason.create!(
      code: "slice1_custom",
      name: "Slice One Custom",
      direction: "either",
      description: "Original notes",
      cost_required_for_increase: true,
      notes_required: false
    )
  end

  test "index uses the page frame at standard width" do
    sign_in_as("admin")
    get admin_adjustment_reasons_path
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".admin-page__tools", count: 0
    assert_select ".page-header__title", text: "Adjustment reasons"
    assert_select "a", text: "New reason"
    assert_select "td a", text: "opening_inventory"
    assert_select "main.app-content.app-content--narrow", count: 0
  end

  test "show uses the page frame at standard width" do
    sign_in_as("admin")
    get admin_adjustment_reason_path(@reversal)
    assert_response :success
    assert_page_frame modifier: "standard"
    assert_select ".admin-page__tools", count: 0
    assert_select ".page-header__title", text: @reversal.name
    assert_select ".page-header__subtitle", text: "reversal"
    assert_select ".definition-list"
    assert_select "a", text: "Edit", count: 0
  end

  test "new uses the page frame at narrow width and keeps the frozen form" do
    sign_in_as("admin")
    get new_admin_adjustment_reason_path
    assert_response :success
    assert_page_frame modifier: "narrow"
    assert_frozen_form persisted: false
  end

  test "edit uses the page frame at narrow width and keeps the frozen form" do
    sign_in_as("admin")
    get edit_admin_adjustment_reason_path(@custom)
    assert_response :success
    assert_page_frame modifier: "narrow"
    assert_frozen_form persisted: true, reason: @custom
  end

  test "failed create redisplays narrow with retained values" do
    sign_in_as("admin")
    post admin_adjustment_reasons_path, params: {
      adjustment_reason: {
        name: "Kept name",
        description: "Kept description",
        direction: "decrease",
        cost_required_for_increase: "0",
        notes_required: "1"
      }
    }
    assert_response :unprocessable_entity
    assert_page_frame modifier: "narrow"
    assert_select "input[name='adjustment_reason[name]'][value='Kept name']"
    assert_select "textarea[name='adjustment_reason[description]']", text: "Kept description"
    assert_select "select[name='adjustment_reason[direction]'] option[selected][value=decrease]"
  end

  test "failed update redisplays narrow with retained values" do
    sign_in_as("admin")
    patch admin_adjustment_reason_path(@custom), params: {
      adjustment_reason: {
        name: "",
        description: "Kept notes",
        direction: @custom.direction,
        lock_version: @custom.lock_version
      }
    }
    assert_response :unprocessable_entity
    assert_page_frame modifier: "narrow"
    assert_select "input[name='adjustment_reason[name]'][value='']"
    assert_select "textarea[name='adjustment_reason[description]']", text: "Kept notes"
  end

  test "unmigrated users index has no width modifier" do
    sign_in_as("admin")
    get admin_users_path
    assert_response :success
    assert_select "main[class='app-content']"
    assert_select "main.app-content.app-content--narrow", count: 0
    assert_select "main.app-content.app-content--standard", count: 0
    assert_select "main.app-content.app-content--wide", count: 0
    assert_select "main.app-content.app-content--workspace", count: 0
    assert_select ".admin-page", count: 0
  end

  test "page-frame CSS keeps content-max as the standard authority" do
    css = Rails.root.join("app/assets/stylesheets/application.css").read
    block_start = css.index(".app-content--narrow")
    block_end = css.index(".ops-header,")
    assert block_start
    assert block_end
    block = css[block_start...block_end]

    assert_match(/\.app-content \{\s*width:\s*min\(100% - 2rem, var\(--content-max\)\)/m, css)
    assert_match(/--content-max:\s*72rem/, css[/:root\s*\{[^}]+\}/m])
    assert_match(/width:\s*min\(100% - 2rem, var\(--content-max\)\)/, css[/\.app-content--standard\s*\{[^}]+\}/])
    assert_match(/width:\s*min\(100% - 2rem, var\(--admin-content-narrow\)\)/, css[/\.app-content--narrow\s*\{[^}]+\}/])
    assert_match(/width:\s*min\(100% - 2rem, var\(--admin-content-wide\)\)/, css[/\.app-content--wide\s*\{[^}]+\}/])
    assert_match(/width:\s*calc\(100% - 2rem\)/, css[/\.app-content--workspace\s*\{[^}]+\}/])
    refute_match(/100vw/, block)
    refute_match(/transform\s*:/, block)
    refute_match(/margin(?:-left|-right|-inline|-block|-top|-bottom)?\s*:\s*-/, block)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def assert_page_frame(modifier:)
    assert_select ".admin-page", count: 1
    assert_select "main.app-content .admin-page", count: 1
    assert_select ".admin-page .admin-page", count: 0
    assert_select "h1", count: 1
    assert_select "main[class='app-content app-content--#{modifier}']"
  end

  def assert_frozen_form(persisted:, reason: nil)
    assert_select "form.form"
    assert_select "input[name='adjustment_reason[name]']"
    assert_select "textarea[name='adjustment_reason[description]']"
    assert_select "select[name='adjustment_reason[direction]']"
    assert_select "input[name='adjustment_reason[cost_required_for_increase]'][type=checkbox]"
    assert_select "input[name='adjustment_reason[notes_required]'][type=checkbox]"
    if persisted
      assert_select "input[name='adjustment_reason[code]']", count: 0
      assert_select "input[name='adjustment_reason[lock_version]'][type=hidden]"
      assert_select "form.form button", text: "Save Changes"
      assert_select "a", text: "Cancel" do |links|
        assert_equal admin_adjustment_reason_path(reason), links.first["href"]
      end
    else
      assert_select "input[name='adjustment_reason[code]']"
      assert_select "form.form button", text: "Create Adjustment Reason"
      assert_select "a", text: "Cancel" do |links|
        assert_equal admin_adjustment_reasons_path, links.first["href"]
      end
    end
  end
end
