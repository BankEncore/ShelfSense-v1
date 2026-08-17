# frozen_string_literal: true

require "test_helper"

class RegistersAdminTest < ActionDispatch::IntegrationTest
  setup do
    bootstrap!
  end

  test "admin can create a register with register_number" do
    sign_in_as("admin")

    get new_admin_register_path
    assert_response :success

    assert_difference -> { Register.count }, 1 do
      post admin_registers_path, params: {
        register: { register_number: "01", name: "Front Register", description: "Main checkout" }
      }
    end

    register = Register.find_by!(register_number: 1)
    assert_redirected_to admin_register_path(register)
    assert_equal "Front Register", register.name
    assert_equal 1, register.register_number
    event = AuditEvent.order(:created_at).last
    assert_equal "registers.create", event.action
    assert_equal register.id, event.register_id
  end

  test "direct unauthorized register create is denied" do
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
    post admin_registers_path, params: {
      register: { register_number: 9, name: "Unauthorized" }
    }
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied").order(:created_at).last.outcome
    assert_not Register.exists?(register_number: 9)
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
