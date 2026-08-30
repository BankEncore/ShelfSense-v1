# frozen_string_literal: true

require "test_helper"

class PosCustomerServiceSurfacesTest < ActionDispatch::IntegrationTest
  setup do
    @bootstrap = bootstrap!
    @store = @bootstrap[:store]
    @actor = @bootstrap[:administrator]
    @register = Register.create!(store: @store, register_number: 1, name: "Front")
    @tax = tax_class(code: "physical_book", name: "Physical book")
    @variant = pos_sellable_variant(actor: @actor, tax_class: @tax)
    sign_in_as("admin")
  end

  test "customer summary is read-only inside the shell" do
    customer = Customer.create!(display_name: "Summary Customer", email: "summary@example.com", phone: "555-0144")
    account = StoredValue::OpenAccount.call(account_type: "store_credit", customer: customer)
    reason = StoredValueAdjustmentReason.find_by!(code: "goodwill")
    StoredValue::Adjust.call(
      account: account,
      direction: "credit",
      amount_cents: 1_800,
      reason: reason,
      store: @store,
      performed_by: @actor,
      source_id: account.id,
      idempotency_key: SecureRandom.uuid_v7
    )

    get pos_customer_summary_path, params: { register_id: @register.id, customer_id: customer.id }
    assert_response :success
    assert_select ".pos-register-shell"
    assert_select "h1", text: "Customer Summary"
    assert_match "Summary Customer", response.body
    assert_match format_money_cents(1_800), response.body
    assert_select "a", text: "Open Customer"
    refute_match(/Attach/i, response.body)
    refute_match(/Merge/i, response.body)
    refute_match(/Edit customer/i, response.body)
  end

  test "customer summary search lists matches without mutation controls" do
    Customer.create!(display_name: "Alpha Search", email: "alpha.search@example.com")
    get pos_customer_summary_path, params: { q: "Alpha Search" }
    assert_response :success
    assert_match "Alpha Search", response.body
    assert_select "form[method='post']", count: 0
  end

  test "pickup queue is view-only and lists available requests" do
    customer = Customer.create!(display_name: "Pickup Customer", phone: "555-0188")
    request = create_available_request!(customer:)

    get pos_pickup_queue_path, params: { register_id: @register.id }
    assert_response :success
    assert_select ".pos-register-shell"
    assert_select "h1", text: "Pickup Queue"
    assert_match(/##{request.number}/, response.body)
    assert_match "Pickup Customer", response.body
    assert_match "View only", response.body
    assert_select "a", text: /Add .* Transaction/i, count: 0
    assert_select "form[action*='pickup'][method='post']", count: 0
  end

  test "pickup queue and customer summary do not create sessions on GET" do
    get pos_customer_summary_path
    get pos_pickup_queue_path
    assert_response :success
    refute PosSession.open.exists?
    refute PosReportingPeriod.exists?
  end

  private

  def sign_in_as(username)
    post session_path, params: { session: { username: username, password: "correct-horse-battery" } }
  end

  def format_money_cents(cents)
    format("$%d.%02d", cents / 100, cents % 100)
  end

  def create_available_request!(customer:)
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 2)
    request = CustomerRequest.create!(
      store: @store,
      customer: customer,
      product_variant: @variant,
      number: (CustomerRequest.where(store: @store).maximum(:number) || 0) + 1,
      status: "available",
      requested_quantity: 1
    )
    CustomerRequestAllocation.create!(
      customer_request: request,
      allocation_type: "standard_quantity",
      status: "reserved",
      quantity: 1
    )
    request
  end
end
