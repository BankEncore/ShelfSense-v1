# frozen_string_literal: true

require "test_helper"

class Phase2AdminAuthzTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @associate = User.create!(
      username: "associate",
      display_name: "Associate User",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: @associate,
      role: Role.find_by!(key: "associate"),
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )
  end

  test "admin can create GL accounts and tax classes" do
    sign_in_as("admin")

    post admin_gl_accounts_path, params: {
      gl_account: {
        account_number: "1200",
        name: "Inventory",
        account_type: "asset",
        account_category: "inventory",
        posting_allowed: "1",
        display_order: 0
      }
    }
    assert_response :redirect
    assert GlAccount.exists?(account_number: "1200")

    post admin_tax_classes_path, params: {
      tax_class: { code: "taxable", name: "Taxable", display_order: 0 }
    }
    assert_response :redirect
    assert TaxClass.exists?(code: "taxable")
  end

  test "associate is denied gl_accounts.create" do
    sign_in_as("associate")

    post admin_gl_accounts_path, params: {
      gl_account: {
        account_number: "1300",
        name: "Denied",
        account_type: "asset",
        account_category: "cash",
        posting_allowed: "1",
        display_order: 0
      }
    }
    assert_redirected_to root_path
    assert_not GlAccount.exists?(account_number: "1300")
    assert_equal "denied", AuditEvent.where(action: "authorization.denied").order(:created_at).last.outcome
  end

  test "associate may use merchandise.lookup" do
    sign_in_as("associate")

    get new_admin_merchandise_lookup_path
    assert_response :success

    post admin_merchandise_lookups_path, params: { lookup: { raw: external_isbn13 } }
    assert_response :success
    assert_match(/not_found|Status/i, response.body)
  end

  test "merchandise.import requires merchandise.import permission" do
    sign_in_as("associate")

    get new_admin_merchandise_import_path
    assert_redirected_to root_path

    sign_in_as("admin")
    get new_admin_merchandise_import_path
    assert_response :success
  end

  private

  def sign_in_as(username)
    delete session_path
    follow_redirect! while response.redirect?
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
    follow_redirect! if response.redirect?
  end
end
