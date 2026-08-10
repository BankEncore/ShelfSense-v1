# frozen_string_literal: true

require "test_helper"

class Authentication::SignInTest < ActiveSupport::TestCase
  setup do
    @bootstrap = Installation::Bootstrap.call(
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

  test "signs in an active human user" do
    result = Authentication::SignIn.call(username: "admin", password: "correct-horse-battery")

    assert result.success?
    assert_equal @bootstrap[:administrator].id, result.user.id
    assert result.session.persisted?
    assert result.raw_token.present?
    assert_equal "succeeded", AuditEvent.where(action: "authentication.sign_in").order(:created_at).last.outcome
  end

  test "rejects invalid password" do
    result = Authentication::SignIn.call(username: "admin", password: "wrong-password-value")

    assert_not result.success?
    assert_equal 1, @bootstrap[:administrator].reload.failed_sign_in_count
    assert_equal "failed", AuditEvent.where(action: "authentication.sign_in").order(:created_at).last.outcome
  end

  test "rejects system actor" do
    result = Authentication::SignIn.call(username: "system", password: "anything-at-all")

    assert_not result.success?
  end

  test "rejects inactive users" do
    user = @bootstrap[:administrator]
    second = User.create!(
      username: "other",
      display_name: "Other",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: second,
      role: Role.find_by!(key: "system_administrator"),
      assigned_by: user,
      effective_at: Time.current
    )
    Users::Deactivate.call(user: user, actor: second)

    result = Authentication::SignIn.call(username: "admin", password: "correct-horse-battery")
    assert_not result.success?
    assert_equal 0, user.user_sessions.active.count
  end
end
