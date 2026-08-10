# frozen_string_literal: true

require "test_helper"

class Phase1FlowTest < ActionDispatch::IntegrationTest
  setup do
    Installation::Bootstrap.call(
      organization_name: "Example Books",
      store_number: "1",
      store_code: "main",
      store_name: "Main Store",
      store_timezone: "America/New_York",
      store_country_code: "US",
      admin_username: "admin",
      admin_display_name: "Admin User",
      admin_password: "correct-horse-battery"
    )
  end

  test "sign in administer settings and browse audit" do
    get new_session_path
    assert_response :success

    post session_path, params: { session: { username: "admin", password: "correct-horse-battery" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success

    get admin_system_settings_path
    assert_response :success

    settings = SystemSettings.current
    patch admin_system_settings_path, params: {
      system_settings: {
        organization_name: "Example Books Updated",
        legal_name: settings.legal_name,
        base_currency_code: settings.base_currency_code,
        default_timezone: settings.default_timezone,
        default_country_code: settings.default_country_code,
        default_region_code: settings.default_region_code,
        fiscal_year_start_month: settings.fiscal_year_start_month,
        default_supplier_cancellation_days: settings.default_supplier_cancellation_days,
        default_customer_reservation_expiration_days: settings.default_customer_reservation_expiration_days,
        default_receipt_header: settings.default_receipt_header,
        default_receipt_footer: settings.default_receipt_footer,
        lock_version: settings.lock_version
      }
    }
    assert_redirected_to admin_system_settings_path
    assert_equal "Example Books Updated", SystemSettings.current.organization_name

    get admin_audit_events_path
    assert_response :success
    assert_match "system_settings.update", response.body
  end

  test "direct unauthorized access is denied" do
    manager = User.create!(
      username: "manager",
      display_name: "Manager",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: manager,
      role: Role.find_by!(key: "store_manager"),
      store: Store.first,
      assigned_by: User.find_by!(username: "admin"),
      effective_at: Time.current
    )

    post session_path, params: { session: { username: "manager", password: "correct-horse-battery" } }
    get admin_users_path
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied").order(:created_at).last.outcome
  end

  test "stale lock_version surfaces a conflict" do
    post session_path, params: { session: { username: "admin", password: "correct-horse-battery" } }
    settings = SystemSettings.current
    stale = settings.lock_version
    settings.update!(organization_name: "Concurrent Edit")

    patch admin_system_settings_path, params: {
      system_settings: {
        organization_name: "Stale Edit",
        base_currency_code: settings.base_currency_code,
        default_timezone: settings.default_timezone,
        default_country_code: settings.default_country_code,
        fiscal_year_start_month: settings.fiscal_year_start_month,
        default_supplier_cancellation_days: settings.default_supplier_cancellation_days,
        default_customer_reservation_expiration_days: settings.default_customer_reservation_expiration_days,
        lock_version: stale
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_match(/changed by someone else|try again/i, flash[:alert].to_s + response.body)
    assert_equal "Concurrent Edit", SystemSettings.current.organization_name
  end
end
