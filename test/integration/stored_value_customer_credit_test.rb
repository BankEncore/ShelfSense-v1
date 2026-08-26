# frozen_string_literal: true

require "test_helper"

class StoredValueCustomerCreditTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @approver = create_store_manager("sv_ui_approver")
    @customer = Customer.create!(display_name: "SV Customer", email: "sv.ui@example.com")
    @goodwill = StoredValueAdjustmentReason.find_by!(code: "goodwill")
  end

  test "customer show displays balances to staff with view_activity" do
    account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    StoredValue::Post.call(
      operation_type: "issue",
      store: @store,
      performed_by: @admin,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7,
      entries: [ { account: account, amount_cents: 125 } ]
    )

    sign_in_as("admin")
    get admin_customer_path(@customer)
    assert_response :success
    assert_includes response.body, "Stored value"
    assert_includes response.body, "Store credit"
    assert_includes response.body, format_cents(125)
    assert_includes response.body, "Store credit activity"
    assert_includes response.body, "Issue"
  end

  test "customer show hides stored-value balances without view_activity" do
    StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    create_customers_viewer("sv_view_only")
    sign_in_as("sv_view_only")
    post store_selection_path, params: { store_id: @store.id }
    get admin_customer_path(@customer)
    assert_response :success
    assert_not_includes response.body, "Stored value"
  end

  test "closed store-credit accounts remain in activity history" do
    account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: @customer)
    StoredValue::Post.call(
      operation_type: "issue",
      store: @store,
      performed_by: @admin,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7,
      entries: [ { account: account, amount_cents: 50 } ]
    )
    StoredValue::Post.call(
      operation_type: "adjust",
      store: @store,
      performed_by: @admin,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7,
      entries: [ { account: account.reload, amount_cents: -50 } ]
    )
    account.reload.close_zero!

    sign_in_as("admin")
    get admin_customer_path(@customer)
    assert_response :success
    assert_includes response.body, "Closed"
    assert_includes response.body, "Store credit activity"
    assert_includes response.body, "Adjust"
  end

  test "opening the adjust form does not create an account" do
    sign_in_as("admin")
    assert_no_difference("StoredValueAccount.count") do
      get new_admin_customer_stored_value_adjustment_path(@customer, account_type: "store_credit")
    end
    assert_response :success
  end

  test "staff can post a store-credit credit from customer show" do
    sign_in_as("admin")
    post admin_customer_stored_value_adjustments_path(@customer), params: {
      account_type: "store_credit",
      direction: "credit",
      amount: "12.50",
      reason_id: @goodwill.id,
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to admin_customer_path(@customer)
    account = StoredValueAccount.find_by!(customer: @customer, account_type: "store_credit")
    assert_equal 1250, account.balance_cents
  end

  test "deactivate is blocked while store credit is nonzero and allowed at zero" do
    sign_in_as("admin")
    post admin_customer_stored_value_adjustments_path(@customer), params: {
      account_type: "store_credit",
      direction: "credit",
      amount: "5.00",
      reason_id: @goodwill.id,
      idempotency_key: SecureRandom.uuid_v7
    }
    delete admin_customer_path(@customer)
    follow_redirect!
    assert_match(/nonzero store-credit or trade-credit balance/, flash[:alert].to_s + response.body)
    assert @customer.reload.active?

    debit_reason = StoredValueAdjustmentReason.find_by!(code: "correction_debit")
    post admin_customer_stored_value_adjustments_path(@customer), params: {
      stored_value_account_id: StoredValueAccount.find_by!(customer: @customer, account_type: "store_credit").id,
      direction: "debit",
      amount: "5.00",
      reason_id: debit_reason.id,
      internal_notes: "clear before deactivate",
      approver_username: @approver.username,
      approver_password: "correct-horse-battery",
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to admin_customer_path(@customer)

    delete admin_customer_path(@customer)
    assert_redirected_to admin_customers_path
    assert_not @customer.reload.active?
  end

  test "administrative transfer requires a second user and posts to the destination" do
    source = Customer.create!(display_name: "From SV", email: "sv.from@example.com")
    destination = Customer.create!(display_name: "To SV", email: "sv.to@example.com")
    account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: source)
    StoredValue::Post.call(
      operation_type: "issue",
      store: @store,
      performed_by: @admin,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7,
      entries: [ { account: account, amount_cents: 800 } ]
    )

    sign_in_as("admin")
    post admin_stored_value_transfers_path, params: {
      from_customer_id: source.id,
      to_customer_id: destination.id,
      account_type: "store_credit",
      transfer_type: "administrative",
      amount: "3.00",
      reason_code: "misapplied",
      approver_username: @approver.username,
      approver_password: "correct-horse-battery",
      idempotency_key: SecureRandom.uuid_v7
    }
    assert_redirected_to admin_customer_path(destination)
    assert_equal 500, account.reload.balance_cents
    dest_account = StoredValueAccount.find_by!(customer: destination, account_type: "store_credit")
    assert_equal 300, dest_account.balance_cents
    assert account.active?
  end

  test "associates cannot adjust stored value" do
    associate = User.create!(
      username: "sv_associate",
      display_name: "SV Associate",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: associate,
      role: Role.find_by!(key: "associate"),
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )
    sign_in_as("sv_associate")
    post store_selection_path, params: { store_id: @store.id }
    post admin_customer_stored_value_adjustments_path(@customer), params: {
      account_type: "store_credit",
      direction: "credit",
      amount: "1.00",
      reason_id: @goodwill.id
    }
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied", actor_user: associate).order(:created_at).last.outcome
  end

  test "adjustment reasons catalog is reachable from organization navigation" do
    sign_in_as("admin")
    get admin_stored_value_adjustment_reasons_path
    assert_response :success
    assert_includes response.body, "goodwill"
    get admin_products_path
    assert_includes response.body, admin_stored_value_adjustment_reasons_path
    assert_includes response.body, new_admin_stored_value_transfer_path
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def format_cents(cents)
    ApplicationController.helpers.format_money_cents(cents)
  end

  def create_store_manager(username)
    user = User.create!(
      username: username,
      display_name: username.titleize,
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: Role.find_by!(key: "store_manager"),
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )
    user
  end

  def create_customers_viewer(username)
    role = Role.create!(
      key: "sv_cust_view_#{SecureRandom.hex(3)}",
      name: "Customer view only",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "customers.view"),
      granted_by: @admin
    )
    user = User.create!(
      username: username,
      display_name: username.titleize,
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: user,
      role: role,
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )
    user
  end
end
