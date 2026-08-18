# frozen_string_literal: true

require "test_helper"

class TenderTypesAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @cash = TenderType.find_by!(code: "cash")
  end

  test "admin can create an Other identity and cannot recategorize Cash" do
    sign_in_as("admin")

    post admin_tender_types_path, params: {
      tender_type: {
        code: "campus_charge",
        name: "Campus Charge",
        behavioral_category: "cash",
        external_reference_policy: "required"
      }
    }
    other = TenderType.find_by!(code: "campus_charge")
    assert_redirected_to admin_tender_type_path(other)
    assert_equal "other", other.behavioral_category
    assert_not other.system_protected?
    assert AuditEvent.exists?(action: "tender_types.create", subject_id: other.id)

    patch admin_tender_type_path(@cash), params: {
      tender_type: {
        name: "Cash drawer",
        behavioral_category: "other",
        active: false,
        lock_version: @cash.lock_version
      }
    }
    @cash.reload
    assert_redirected_to admin_tender_type_path(@cash)
    assert_equal "Cash drawer", @cash.name
    assert_equal "cash", @cash.behavioral_category
    assert @cash.active?
    assert AuditEvent.exists?(action: "tender_types.update", subject_id: @cash.id)
  end

  test "associate is denied tender type administration" do
    associate = User.create!(
      username: "clerk",
      display_name: "Clerk",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: Store.first,
      assigned_by: User.find_by!(username: "admin"),
      effective_at: Time.current
    )

    sign_in_as("clerk")
    post admin_tender_types_path, params: {
      tender_type: { code: "denied", name: "Denied", external_reference_policy: "optional" }
    }
    assert_redirected_to root_path
    assert_not TenderType.exists?(code: "denied")
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
