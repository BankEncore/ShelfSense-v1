# frozen_string_literal: true

require "test_helper"

class CustomerRequestsAdminTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @admin = @bootstrap[:administrator]
    @store = @bootstrap[:store]
    @tax = tax_class(code: "request_admin_#{SecureRandom.hex(2)}")
    @variant = pos_sellable_variant(actor: @admin, tax_class: @tax, name: "Accessible Lookup Book")
    supplier = Supplier.create!(name: "Lookup Supplier", code: "lookup_#{SecureRandom.hex(2)}")
    SupplierVariantSource.create!(
      supplier: supplier,
      product_variant: @variant,
      pricing_method: "direct_unit_cost",
      expected_unit_cost_cents: 500,
      organization_preferred: true
    )
    @customer = Customer.create!(
      display_name: "Alex Similar",
      phone: "555-0199",
      email: "alex.lookup@example.com"
    )
    @request = Customers::CreateRequest.call(
      store: @store,
      customer: @customer,
      product_variant: @variant,
      actor: @admin
    )
  end

  test "new request looks up customers and merchandise without raw ids" do
    sign_in_as("admin")
    select_store

    get customer_lookup_admin_customer_requests_path, params: { customer_q: "555-0199" }
    assert_response :success
    assert_includes response.body, "Alex Similar"
    assert_includes response.body, "alex.lookup@example.com"
    assert_includes response.body, @customer.id

    get merchandise_lookup_admin_customer_requests_path, params: { merchandise_q: @variant.sku }
    assert_response :success
    assert_includes response.body, "Accessible Lookup Book"
    assert_includes response.body, "Standard"
    assert_includes response.body, "Available"

    get new_admin_customer_request_path
    assert_response :success
    assert_no_match(/Product variant ID/, response.body)
  end

  test "creating a customer returns to preserved request state" do
    sign_in_as("admin")
    select_store
    return_to = new_admin_customer_request_path(
      product_variant_id: @variant.id,
      customer_request: { notes: "Keep these notes", estimated_price_cents: "12.34" }
    )

    post admin_customers_path, params: {
      return_to: return_to,
      customer: { display_name: "Inline Customer", phone: "555-0101" }
    }

    customer = Customer.find_by!(display_name: "Inline Customer")
    assert response.redirect?
    assert_equal new_admin_customer_request_path, URI.parse(response.location).path
    assert_includes response.location, "customer_id=#{customer.id}"
    assert_includes response.location, "Keep+these+notes"
  end

  test "index searches filters sorts active first and paginates" do
    @request.update_columns(status: "completed", updated_at: Time.current) # historical fixture setup
    active_customer = Customer.create!(display_name: "Current Reader", phone: "555-0110")
    active_request = Customers::CreateRequest.call(
      store: @store,
      customer: active_customer,
      product_variant: @variant,
      actor: @admin
    )
    sign_in_as("admin")
    select_store

    get admin_customer_requests_path, params: { q: "Current Reader", status: active_request.status }
    assert_response :success
    assert_includes response.body, "Current Reader"
    assert_not_includes response.body, "Alex Similar"
    assert_includes response.body, "Page 1 of 1"

    get admin_customer_requests_path
    assert_operator response.body.index("##{active_request.number}"), :<, response.body.index("##{@request.number}")
  end

  test "show presents current promise and chronological fulfillment summary" do
    sign_in_as("admin")
    select_store

    get admin_customer_request_path(@request)

    assert_response :success
    assert_select "h2", text: "Needs locating"
    assert_select "h2", text: "Fulfillment timeline"
    assert_select ".request-summary", text: /Alex Similar/
    assert_select ".request-summary", text: /555-0199/
    assert_select ".request-summary", text: /Accessible Lookup Book/
    assert_select ".request-summary", text: /Pending location/
    assert_select ".request-next-action a", text: "Open location queue"
    assert_select ".fulfillment-timeline__event", minimum: 1, text: /Request created/
    assert_select "details.technical-details", text: /Request ID/
  end

  test "lookup endpoints deny direct requests without management permission" do
    viewer = User.create!(
      username: "request_viewer",
      display_name: "Request Viewer",
      password: "correct-horse-battery",
      password_confirmation: "correct-horse-battery"
    )
    role = Role.create!(key: "request_viewer", name: "Request Viewer", assignment_scope: "store")
    permission = Permission.find_by!(key: "customers.view")
    RolePermission.create!(role: role, permission: permission, granted_by: @admin)
    RoleAssignment.create!(user: viewer, role: role, store: @store, assigned_by: @admin, effective_at: Time.current)
    sign_in_as("request_viewer")
    select_store

    get customer_lookup_admin_customer_requests_path, params: { customer_q: @customer.email }
    assert_redirected_to root_path
    get merchandise_lookup_admin_customer_requests_path, params: { merchandise_q: @variant.sku }
    assert_redirected_to root_path
    assert_equal 2, AuditEvent.where(action: "authorization.denied", actor_user: viewer).count
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def select_store
    post store_selection_path, params: { store_id: @store.id }
  end
end
