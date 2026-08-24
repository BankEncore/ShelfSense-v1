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

  test "admin index search finds by name substring" do
    Customer.create!(display_name: "Zelda Searchable", email: "zelda@example.com")
    Customer.create!(display_name: "Other Person", email: "other@example.com")
    sign_in_as("admin")

    get admin_customers_path, params: { q: "Zelda" }
    assert_response :success
    assert_includes response.body, "Zelda Searchable"
    assert_not_includes response.body, "Other Person"
  end

  test "duplicate warning blocks create until acknowledged" do
    Customer.create!(display_name: "Dup Person", email: "dup@example.com", phone: "555-777-7777")
    sign_in_as("admin")

    post admin_customers_path, params: {
      customer: { display_name: "Someone Else", email: "dup@example.com" }
    }
    assert_response :unprocessable_entity
    assert_includes response.body, "Possible duplicates"
    assert_nil Customer.find_by(display_name: "Someone Else")

    post admin_customers_path, params: {
      customer: { display_name: "Someone Else", email: "dup@example.com" },
      acknowledge_duplicates: "1"
    }
    assert_redirected_to admin_customer_path(Customer.find_by!(display_name: "Someone Else"))
  end

  test "structured name only create still triggers weak duplicate warning" do
    Customer.create!(display_name: "Jamie Lee Reader", email: "jamie.lee@example.com", phone: "555-222-3333")
    sign_in_as("admin")

    post admin_customers_path, params: {
      customer: {
        given_name: "Jamie",
        family_name: "Lee",
        email: "new.jamie@example.com"
      }
    }
    assert_response :unprocessable_entity
    assert_includes response.body, "Possible duplicates"
    assert_nil Customer.find_by(email: "new.jamie@example.com")
  end

  test "structured name only update still triggers weak duplicate warning" do
    existing = Customer.create!(display_name: "Jamie Lee Reader", email: "jamie.update@example.com", phone: "555-222-4444")
    editing = Customer.create!(display_name: "Other Person", email: "other.update@example.com", phone: "555-222-5555")
    sign_in_as("admin")

    patch admin_customer_path(editing), params: {
      customer: {
        display_name: "",
        given_name: "Jamie",
        family_name: "Lee",
        email: editing.email,
        phone: editing.phone,
        lock_version: editing.lock_version
      }
    }
    assert_response :unprocessable_entity
    assert_includes response.body, "Possible duplicates"
    assert_equal "Other Person", editing.reload.display_name
    assert_equal existing.display_name, "Jamie Lee Reader"
  end

  test "default index search resolves alias match to survivor" do
    survivor = Customer.create!(display_name: "Canonical Survivor", email: "canon@example.com", phone: "555-333-0001")
    source = Customer.create!(display_name: "Former Alias", email: "former@example.com", phone: "555-333-0002")
    Customers::MergeCustomers.call(
      source: source,
      survivor: survivor,
      actor: @admin,
      reason: "dedupe",
      idempotency_key: SecureRandom.uuid_v7
    )
    sign_in_as("admin")

    get admin_customers_path, params: { q: "555-333-0002" }
    assert_response :success
    assert_includes response.body, "Canonical Survivor"
    assert_includes response.body, "matched former record"
    assert_not_includes response.body, ">Former Alias<"
  end

  test "merge review and confirm merges customers" do
    source = Customer.create!(display_name: "Merge Source", email: "ms@example.com", phone: "555-800-0000")
    survivor = Customer.create!(display_name: "Merge Survivor", email: "mv@example.com", phone: "555-800-0001")
    sign_in_as("admin")

    get merge_review_admin_customer_path(source), params: { survivor_id: survivor.id }
    assert_response :success
    assert_includes response.body, "Merge review"

    post merge_admin_customer_path(source), params: {
      survivor_id: survivor.id,
      reason: "same household",
      idempotency_key: SecureRandom.uuid_v7,
      source_lock_version: source.lock_version,
      survivor_lock_version: survivor.lock_version
    }
    assert_redirected_to admin_customer_path(survivor)
    assert source.reload.merged?
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
