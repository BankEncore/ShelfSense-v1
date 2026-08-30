# frozen_string_literal: true

require "test_helper"

class PosQuickCustomerTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @admin = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    sign_in_as("admin")
  end

  test "quick customer creates attaches and explains missing store-credit account" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    key = SecureRandom.uuid_v7

    post pos_register_quick_customer_path(register_id: @register.id), params: {
      display_name: "Register Quick Reader",
      email: "register.quick@example.com",
      idempotency_key: key,
      lock_version: transaction.lock_version,
      credit_account_type: "store_credit",
      require_contact: "1"
    }
    assert_response :success

    customer = Customer.find_by!(display_name: "Register Quick Reader")
    assert_equal customer.id, transaction.reload.customer_id
    assert_empty StoredValueAccount.where(customer_id: customer.id)
    assert_match "No eligible store-credit account is available yet.", response.body
    assert AuditEvent.exists?(action: "customers.create", subject_id: customer.id)
  end

  test "quick customer idempotent retry does not create a second customer" do
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)
    key = SecureRandom.uuid_v7
    params = {
      display_name: "Retry Quick Reader",
      phone: "555-901-0101",
      idempotency_key: key,
      lock_version: transaction.lock_version
    }

    post pos_register_quick_customer_path(register_id: @register.id), params: params
    assert_response :success
    post pos_register_quick_customer_path(register_id: @register.id), params: params.merge(
      lock_version: transaction.reload.lock_version
    )
    assert_response :success
    assert_equal 1, Customer.where(display_name: "Retry Quick Reader").count
  end

  test "quick customer requires customers.create permission" do
    cashier = User.create!(
      username: "quick_cashier",
      display_name: "Quick Cashier",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    role = Role.create!(
      key: "quick_cashier_#{SecureRandom.hex(3)}",
      name: "Quick Cashier",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    %w[pos.transact customers.create].each do |permission_key|
      RolePermission.create!(
        role: role,
        permission: Permission.find_by!(key: permission_key),
        granted_by: @admin
      )
    end
    RoleAssignment.create!(
      user: cashier,
      role: role,
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )

    delete session_path
    sign_in_as("quick_cashier")
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_quick_customer_path(register_id: @register.id), params: {
      display_name: "Permitted Quick Reader",
      email: "permitted.quick@example.com",
      idempotency_key: SecureRandom.uuid_v7,
      lock_version: transaction.lock_version
    }
    assert_response :success
    assert Customer.exists?(display_name: "Permitted Quick Reader")
  end

  test "quick customer denied without customers.create even with customers.manage" do
    managerish = User.create!(
      username: "manage_only",
      display_name: "Manage Only",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    role = Role.create!(
      key: "manage_only_#{SecureRandom.hex(3)}",
      name: "Manage Only",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    %w[pos.transact customers.manage].each do |permission_key|
      RolePermission.create!(
        role: role,
        permission: Permission.find_by!(key: permission_key),
        granted_by: @admin
      )
    end
    RoleAssignment.create!(
      user: managerish,
      role: role,
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )

    delete session_path
    sign_in_as("manage_only")
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_quick_customer_path(register_id: @register.id), params: {
      display_name: "Denied Quick Reader",
      email: "denied.quick@example.com",
      idempotency_key: SecureRandom.uuid_v7,
      lock_version: transaction.lock_version
    }
    assert_redirected_to root_path
    assert_not Customer.exists?(display_name: "Denied Quick Reader")
  end

  test "quick customer duplicate candidates return json without creating" do
    Customer.create!(display_name: "Dup Quick", email: "dup.quick@example.com", phone: "555-902-0202")
    post pos_register_enter_path, params: enter_params
    follow_redirect!
    transaction = PosTransaction.working.find_by!(register: @register)

    post pos_register_quick_customer_path(register_id: @register.id), params: {
      display_name: "Different Quick",
      email: "dup.quick@example.com",
      idempotency_key: SecureRandom.uuid_v7,
      lock_version: transaction.lock_version
    }, as: :json
    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_equal "duplicates", payload.fetch("error")
    assert payload.fetch("suggestions").any?
    assert_not Customer.exists?(display_name: "Different Quick")
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def enter_params
    {
      register_id: @register.id,
      opening_float: "50.00",
      confirmed_business_date: BusinessDate.for_store(@store).iso8601
    }
  end
end
