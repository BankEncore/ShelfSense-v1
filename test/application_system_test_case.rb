# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  CHROME_BINARIES = %w[/usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome].freeze
  CHROMEDRIVERS = %w[/usr/bin/chromedriver /usr/lib/chromium/chromedriver].freeze

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
end
