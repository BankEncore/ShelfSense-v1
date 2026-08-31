# frozen_string_literal: true

require "test_helper"
require_relative "support/uds_evidence_helpers"
require_relative "support/uds_review_dialog_contract"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include UdsEvidenceHelpers
  include UdsReviewDialogContract

  CHROME_BINARIES = %w[/usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome].freeze
  CHROMEDRIVERS = %w[/usr/bin/chromedriver /usr/lib/chromium/chromedriver].freeze

  # Parallel CI workers routinely need more than Capybara's 2s default for Turbo
  # register enter / workspace morphs. "SALE ENTRY" / "Refund remaining" also appear in
  # the POS JS bundle, so failed asserts report misleading non-visible matches.
  Capybara.default_max_wait_time = 5

  chrome_bin = ENV["CHROME_BIN"].presence || CHROME_BINARIES.find { |path| File.executable?(path) }
  chromedriver = ENV["SE_CHROMEDRIVER"].presence || ENV["CHROMEDRIVER_PATH"].presence ||
    CHROMEDRIVERS.find { |path| File.executable?(path) }

  if chromedriver.present? && File.executable?(chromedriver)
    ENV["SE_CHROMEDRIVER"] ||= chromedriver
    Selenium::WebDriver::Chrome::Service.driver_path = chromedriver
  end

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 720 ] do |options|
    options.binary = chrome_bin if chrome_bin.present?
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
  end

  def with_viewport(width:, height:, zoom: 1)
    page.driver.browser.manage.window.resize_to(width, height)
    page.execute_script("document.documentElement.style.zoom = #{zoom.to_f}") unless zoom == 1
    yield
  ensure
    page.execute_script("document.documentElement.style.zoom = 1")
    page.driver.browser.manage.window.resize_to(1280, 720)
  end

  def sign_in_admin(actor: bootstrap![:administrator])
    visit new_session_path
    fill_in "session_username", with: actor.username
    fill_in "session_password", with: "correct-horse-battery"
    find_field("session_password").send_keys :enter
    assert_text "Signed in successfully"
  end

  def open_register_menu
    send_keys :f10
    assert_selector "#register-menu", visible: true
  end

  def choose_register_menu(label)
    open_register_menu
    click_on label
    assert_no_selector "#register-menu", visible: true
  end

  # Slice 5D/7C: Tender (+) / Refund (+) opens O11; Cash is first in cashier_selectable order.
  # Punctuation `+` is a shortcut only from non-input workspace focus (not the command field).
  def choose_tender_from_overlay(name = "Cash")
    assert_selector "#pos_other_overlay", visible: true
    find("#pos_other_overlay li", text: name).click
    within("#pos_other_overlay") { click_button "Choose Tender" }
    assert_no_selector "#pos_other_overlay", visible: true
  end

  def start_cash_tender_via_plus
    click_on "Tender (+)"
    choose_tender_from_overlay("Cash")
    assert_text "CASH TENDER"
  end

  def start_cash_refund_via_plus
    click_on "Refund (+)"
    choose_tender_from_overlay("Cash")
    assert_text "REFUND"
    field = find("#pos-command-field")
    refute_equal "", field.value
    field.click
  end

  def focus_workspace_background_for_shortcuts
    page.execute_script(<<~JS)
      const root = document.querySelector("[data-register-workspace-target='background']")
      if (!root) throw new Error("workspace background missing")
      if (!root.hasAttribute("tabindex")) root.tabIndex = -1
      root.focus()
    JS
  end

  def open_product_lookup_via_slash
    focus_workspace_background_for_shortcuts
    page.execute_script(<<~JS)
      document.activeElement.dispatchEvent(new KeyboardEvent("keydown", {
        key: "/",
        code: "Slash",
        bubbles: true,
        cancelable: true
      }))
    JS
    assert_selector "#pos_search_overlay", visible: true
  end

  def focus_selected_basket_row
    row = find("tbody tr.is-selected[data-line-id]", wait: 5)
    page.execute_script(<<~JS, row.native)
      const row = arguments[0]
      row.tabIndex = 0
      row.focus()
    JS
    row
  end

  def teardown
    reset_uds_viewport!
  end

  def reset_uds_viewport!
    return unless page.driver.respond_to?(:browser) && page.driver.browser

    page.execute_script("document.documentElement.style.zoom = '1'")
    page.driver.browser.manage.window.resize_to(1280, 720)
  rescue Selenium::WebDriver::Error::WebDriverError, Capybara::NotSupportedByDriverError
    nil
  end
end
