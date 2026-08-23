# frozen_string_literal: true

require "test_helper"

class CustomersAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
  end

  test "admin can create a customer with audit" do
    sign_in_as("admin")

    post admin_customers_path, params: {
      customer: { display_name: "Jamie Reader", email: "jamie@example.com" }
    }
    customer = Customer.find_by!(display_name: "Jamie Reader")
    assert_redirected_to admin_customer_path(customer)
    assert AuditEvent.exists?(action: "customers.create", subject_id: customer.id)
  end

  test "store-scoped customers.view links only accessible requests and denies the rest" do
    east = Store.create!(
      store_number: "2",
      code: "cust_east",
      name: "East Customers Store",
      legal_name: "Example Books LLC",
      timezone: "America/New_York",
      country_code: "US"
    )
    role = Role.create!(
      key: "cust_view_a_#{SecureRandom.hex(3)}",
      name: "Customer view Store A",
      assignment_scope: "store",
      system_role: false,
      active: true
    )
    RolePermission.create!(
      role: role,
      permission: Permission.find_by!(key: "customers.view"),
      granted_by: @admin
    )
    viewer = User.create!(
      username: "cust_view_a",
      display_name: "Customer View A",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    RoleAssignment.create!(
      user: viewer,
      role: role,
      store: @store,
      assigned_by: @admin,
      effective_at: Time.current
    )

    tax = tax_class(code: "cust_xlink_#{SecureRandom.hex(2)}")
    variant = pos_sellable_variant(actor: @admin, tax_class: tax, name: "Scoped Request Book")
    customer = Customer.create!(display_name: "Multi Store Reader", email: "multi.store@example.com")
    open_quantity_stock(store: @store, variant: variant, actor: @admin, quantity: 1)
    open_quantity_stock(store: east, variant: variant, actor: @admin, quantity: 1)

    home_request = Customers::CreateRequest.call(
      store: @store,
      customer: customer,
      product_variant: variant,
      actor: @admin
    )
    east_request = Customers::CreateRequest.call(
      store: east,
      customer: customer,
      product_variant: variant,
      actor: @admin
    )

    sign_in_as("cust_view_a")
    post store_selection_path, params: { store_id: @store.id }

    get admin_customer_path(customer)
    assert_response :success
    assert_select "a[href=?]", admin_customer_request_path(home_request), text: "Request ##{home_request.number}"
    assert_select "a[href=?]", admin_customer_request_path(east_request), count: 0
    assert_includes response.body, "Request ##{east_request.number}"

    get admin_customer_request_path(east_request)
    assert_redirected_to root_path
    assert_equal "denied", AuditEvent.where(action: "authorization.denied", actor_user: viewer).order(:created_at).last.outcome
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end
end
