# frozen_string_literal: true

require "test_helper"

class SystemSettingsValidationTest < ActiveSupport::TestCase
  test "customer reservation days must be positive" do
    actor_user
    settings = SystemSettings.current
    settings.default_customer_reservation_expiration_days = 0
    assert_not settings.valid?
    assert settings.errors[:default_customer_reservation_expiration_days].any?
  end
end
