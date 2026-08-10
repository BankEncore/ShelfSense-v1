# frozen_string_literal: true

namespace :shelfsense do
  desc "Bootstrap a fresh ShelfSense installation"
  task bootstrap: :environment do
    required = %w[
      ORGANIZATION_NAME
      STORE_NUMBER
      STORE_CODE
      STORE_NAME
      STORE_TIMEZONE
      STORE_COUNTRY_CODE
      ADMIN_USERNAME
      ADMIN_DISPLAY_NAME
      ADMIN_PASSWORD
    ]
    missing = required.select { |key| ENV[key].to_s.strip.empty? }
    abort "Missing required environment variables: #{missing.join(', ')}" if missing.any?

    result = Installation::Bootstrap.call(
      organization_name: ENV.fetch("ORGANIZATION_NAME"),
      legal_name: ENV["LEGAL_NAME"],
      store_number: ENV.fetch("STORE_NUMBER"),
      store_code: ENV.fetch("STORE_CODE"),
      store_name: ENV.fetch("STORE_NAME"),
      store_timezone: ENV.fetch("STORE_TIMEZONE"),
      store_country_code: ENV.fetch("STORE_COUNTRY_CODE"),
      admin_username: ENV.fetch("ADMIN_USERNAME"),
      admin_display_name: ENV.fetch("ADMIN_DISPLAY_NAME"),
      admin_password: ENV.fetch("ADMIN_PASSWORD"),
      admin_email: ENV["ADMIN_EMAIL"],
      base_currency_code: ENV.fetch("BASE_CURRENCY_CODE", "USD")
    )

    puts "Bootstrap complete."
    puts "Organization: #{result[:settings].organization_name}"
    puts "Store: #{result[:store].code} (#{result[:store].name})"
    puts "Administrator: #{result[:administrator].username}"
  end
end
