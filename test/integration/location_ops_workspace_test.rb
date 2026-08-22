# frozen_string_literal: true

require "test_helper"

class LocationOpsWorkspaceTest < ActionDispatch::IntegrationTest
  setup do
    bootstrap = bootstrap!
    @store = bootstrap[:store]
    @actor = bootstrap[:administrator]
    tax = tax_class(code: "location_ops_#{SecureRandom.hex(3)}")
    @variant = pos_sellable_variant(actor: @actor, tax_class: tax, name: "Find This Book")
    open_quantity_stock(store: @store, variant: @variant, actor: @actor, quantity: 1, unit_cost_cents: 500)
    @older_customer = Customer.create!(display_name: "Older Reader", phone: "555-0100")
    @newer_customer = Customer.create!(display_name: "Newer Reader", email: "newer@example.com")
    @older_request = create_request(@older_customer)
    @newer_request = create_request(@newer_customer)
    @older_request.update_columns(created_at: 2.days.ago)
    @newer_request.update_columns(created_at: 1.hour.ago)
    post session_path, params: { session: { username: @actor.username, password: "correct-horse-battery" } }
  end

  test "queue is oldest first and presents concise search context with focused actions" do
    get ops_location_path

    assert_response :success
    rows = css_select(".location-queue tbody tr")
    assert_equal [ @older_request.id, @newer_request.id ], rows.map { |row| row["data-request-id"] }
    assert_select ".location-queue tbody tr:first-child", text: /Older Reader/
    assert_select ".location-queue tbody tr:first-child", text: /555-0100/
    assert_select ".location-queue tbody tr:first-child", text: /Find This Book/
    assert_select ".location-queue tbody tr:first-child", text: /Standard/
    assert_select ".location-queue tbody tr:first-child", text: /SKU/
    assert_select ".location-queue tbody tr:first-child", text: /Not categorized/
    assert_select ".location-queue tbody tr:first-child", text: /1/
    # Panels stay closed until Select (?request_id=) or a mutation failure reopens one.
    assert_select ".location-action-panel[hidden]", count: 2
    assert_select ".location-action-panel[data-request-id='#{@older_request.id}']" do
      assert_select "input[name='physical_copy_confirmed'][required]"
      assert_select "button", text: /Reserve for Older Reader/
      assert_select "input[name='resolution'][value='special_order']"
      assert_select "[data-location-queue-target='specialOrderFields'][hidden]"
    end
    assert_select "a[href=?]", ops_location_path(request_id: @older_request.id, mode: "locate"), text: "Select"
  end

  test "selecting a request via query opens that panel server-side" do
    get ops_location_path(request_id: @newer_request.id, mode: "not_located")

    assert_response :success
    assert_select ".location-action-panel:not([hidden])[data-request-id='#{@newer_request.id}']" do
      assert_select "[data-location-queue-target='notLocatedSection']:not([hidden])"
      assert_select "[data-location-queue-target='locateSection'][hidden]"
    end
    assert_select ".location-action-panel[hidden][data-request-id='#{@older_request.id}']"
  end

  test "standard locate requires server-side physical confirmation" do
    post ops_location_confirm_path(@older_request), params: { lock_version: @older_request.lock_version }

    assert_response :unprocessable_entity
    assert_select "[data-ops-error-summary]", text: /physically located/i
    assert_equal "pending_location", @older_request.reload.status

    post ops_location_confirm_path(@older_request), params: {
      lock_version: @older_request.lock_version,
      physical_copy_confirmed: "1"
    }
    assert_redirected_to ops_location_path
    assert_equal "available", @older_request.reload.status
  end

  test "competing locate failure stays inline on the selected request" do
    Customers::ConfirmLocation.call(customer_request: @older_request, actor: @actor)

    post ops_location_confirm_path(@newer_request), params: {
      lock_version: @newer_request.lock_version,
      physical_copy_confirmed: "1"
    }

    assert_response :unprocessable_entity
    assert_select "[data-ops-error-summary]", text: /no available/i
    assert_select ".location-action-panel:not([hidden])[data-request-id='#{@newer_request.id}'] .ops-row-error",
                  text: /no available/i
    assert_equal "pending_location", @newer_request.reload.status
  end

  private

  def create_request(customer)
    Customers::CreateRequest.call(
      store: @store,
      customer: customer,
      product_variant: @variant,
      actor: @actor
    )
  end
end
