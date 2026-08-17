# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 720 ] do |options|
    binary = ENV["CHROME_BIN"].presence ||
      %w[/usr/bin/chromium /usr/bin/chromium-browser /usr/bin/google-chrome].find { |path| File.exist?(path) }
    options.binary = binary if binary.present?
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
  end
end
